//
//  LoopAlgorithm.swift
//  Learn
//
//  Created by Pete Schwamb on 6/30/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit

struct Forecast {
    var predicted: [PredictedGlucoseValue]
}

enum AlgorithmError: Error {
    case missingGlucose
    case incompleteSchedules
}

struct AlgorithmEffectSummary {
    let date: Date

    let netInsulinEffect: HKQuantity
//    let carbsOnBoard: Double // grams
    let insulinOnBoard: Double // IU
//    let momentumEffect: HKQuantity
//    let insulinCounteractionEffects: HKQuantity
//    let retrospectiveCorrection: HKQuantity
}

struct AlgorithmEffectsTimeline {
    let summaries: [AlgorithmEffectSummary]
}

struct AlgorithmInput {
    var glucoseHistory: [StoredGlucoseSample]
    var doses: [DoseEntry]
    var carbEntries: [CarbEntry]
    var basal: [AbsoluteScheduleValue<Double>]
    var sensitivity: [AbsoluteScheduleValue<HKQuantity>]
    var carbRatio: [AbsoluteScheduleValue<Double>]
    var target: [AbsoluteScheduleValue<ClosedRange<HKQuantity>>]
    var delta: TimeInterval = TimeInterval(minutes: 5)
    var insulinActivityDuration: TimeInterval = TimeInterval(hours: 6) + TimeInterval(minutes: 10)
}

actor LoopAlgorithm {

    // Generates a forecast predicting glucose.
    func getForecast(input: AlgorithmInput, startDate: Date? = nil) throws -> Forecast {

        guard let latestGlucose = input.glucoseHistory.last else {
            throw AlgorithmError.missingGlucose
        }

        let start = startDate ?? latestGlucose.startDate

        let insulinModelProvider = PresetInsulinModelProvider(defaultRapidActingModel: nil)

        let effectsInterval = DateInterval(
            start: start.addingTimeInterval(-input.insulinActivityDuration).dateFlooredToTimeInterval(input.delta),
            end: start.addingTimeInterval(input.insulinActivityDuration).dateCeiledToTimeInterval(input.delta)
        )

        // Overlay basal history on basal doses, splitting doses to get amount delivered relative to basal
        let annotatedDoses = input.doses.annotated(with: input.basal)

        let insulinEffects = annotatedDoses.glucoseEffects(
            insulinModelProvider: insulinModelProvider,
            longestEffectDuration: input.insulinActivityDuration,
            insulinSensitivityHistory: input.sensitivity,
            from: effectsInterval.start,
            to: effectsInterval.end)

        // ICE
        let insulinCounteractionEffects = input.glucoseHistory.counteractionEffects(to: insulinEffects)

        // Carb Effects
        let carbEffects = input.carbEntries.map(
            to: insulinCounteractionEffects,
            carbRatio: input.carbRatio,
            insulinSensitivity: input.sensitivity
        ).dynamicGlucoseEffects(
            carbRatios: input.carbRatio,
            insulinSensitivities: input.sensitivity
        )

        // Glucose Momentum
        let momentumEffects = input.glucoseHistory.linearMomentumEffect()

        // RC
        let retrospectiveCorrectionGroupingInterval: TimeInterval = .minutes(30)
        let retrospectiveGlucoseDiscrepancies = insulinCounteractionEffects.subtracting(carbEffects)
        let retrospectiveGlucoseDiscrepanciesSummed = retrospectiveGlucoseDiscrepancies.combinedSums(of: retrospectiveCorrectionGroupingInterval * 1.01)

        let rc = StandardRetrospectiveCorrection(effectDuration: TimeInterval(hours: 1))

        guard let curSensitivity = input.sensitivity.closestPrior(to: start)?.value,
              let curBasal = input.basal.closestPrior(to: start)?.value,
              let curTarget = input.target.closestPrior(to: start)?.value else
        {
            throw AlgorithmError.incompleteSchedules
        }

        let rcEffect = rc.computeEffect(
            startingAt: latestGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: retrospectiveGlucoseDiscrepanciesSummed,
            recencyInterval: TimeInterval(minutes: 15),
            insulinSensitivity: curSensitivity,
            basalRate: curBasal,
            correctionRange: curTarget,
            retrospectiveCorrectionGroupingInterval: retrospectiveCorrectionGroupingInterval
        )

        var effects: [[GlucoseEffect]] = [
            carbEffects,
            insulinEffects,
            rcEffect
        ]

        var prediction = LoopMath.predictGlucose(startingAt: latestGlucose, momentum: momentumEffects, effects: effects)

        return Forecast(predicted: prediction)
    }

    // Provides a timeline of summaries of algorithm effects, to gain insight on algorithm behavior over time.
    static func getEffectsTimeline(
        effectsInterval: DateInterval,
        dataSource: any DataSource,
        delta: TimeInterval = TimeInterval(minutes: 5),
        insulinModelProvider: InsulinModelProvider = PresetInsulinModelProvider(defaultRapidActingModel: nil),
        insulinActivityDuration: TimeInterval = TimeInterval(hours: 6) + TimeInterval(minutes: 10)
    ) async throws -> AlgorithmEffectsTimeline {

        let effectsInterval = DateInterval(
            start: effectsInterval.start.dateFlooredToTimeInterval(delta),
            end: effectsInterval.end.dateCeiledToTimeInterval(delta)
        )

        // Need to go out an extra 6 hours on either end
        let doseFetchInterval = DateInterval(start: effectsInterval.start.addingTimeInterval(-insulinActivityDuration), end: effectsInterval.end.addingTimeInterval(insulinActivityDuration))
        let doses = try await dataSource.getDoses(interval: doseFetchInterval)
        let doseTimespan = doses.timespan

        let settingsTimespan = DateInterval(
            start: min(doseFetchInterval.start, doseTimespan.start),
            end: max(doseFetchInterval.end, doseTimespan.end))

        let basalHistory = try await dataSource.getBasalHistory(interval: settingsTimespan)

        // Overlay basal history on basal doses, splitting doses to get amount delivered relative to basal
        let annotatedDoses = doses.annotated(with: basalHistory)

        // Make sure sensitivity history covers doses that overlap the effectsInterval start
        let sensitivityHistory = try await dataSource.getInsulinSensitivityHistory(interval: settingsTimespan)

        print("Calculating effects over \(effectsInterval)")

        for dose in annotatedDoses {
            print("dose \(dose)")
            print("dose(\(dose.startDate) - \(dose.endDate)) = \(dose.netBasalUnits)")
        }

        let insulinOnBoard = annotatedDoses.insulinOnBoard(
            insulinModelProvider: insulinModelProvider,
            longestEffectDuration: insulinActivityDuration,
            from: effectsInterval.start,
            to: effectsInterval.end)

        var summaries = [AlgorithmEffectSummary]()

        var summaryDate = effectsInterval.start
        var index: Int = 0
        while summaryDate <= effectsInterval.end {
            let insulinEffects = annotatedDoses.glucoseEffects(
                insulinModelProvider: insulinModelProvider,
                longestEffectDuration: insulinActivityDuration,
                insulinSensitivityHistory: sensitivityHistory,
                from: summaryDate,
                to: summaryDate.addingTimeInterval(insulinActivityDuration))

            let netInsulinEffect =
                insulinEffects.last!.quantity.doubleValue(for: .milligramsPerDeciliter) -
                insulinEffects.first!.quantity.doubleValue(for: .milligramsPerDeciliter)

            summaries.append(AlgorithmEffectSummary(
                date: summaryDate,
                netInsulinEffect: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: netInsulinEffect),
                insulinOnBoard: insulinOnBoard[index].value
            ))
            index += 1
            summaryDate = effectsInterval.start + delta * Double(index)
        }

        return AlgorithmEffectsTimeline(summaries: summaries)
    }
}

