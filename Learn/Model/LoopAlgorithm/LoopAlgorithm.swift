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

enum AlgorithmError: Error {
    case missingGlucose
    case incompleteSchedules
}

struct LoopAlgorithmEffects {
    var insulin: [GlucoseEffect]
    var carbs: [GlucoseEffect]
    var retrospectiveCorrection: [GlucoseEffect]
    var momentum: [GlucoseEffect]
    var insulinCounteraction: [GlucoseEffectVelocity]
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

struct AlgorithmEffectsOptions: OptionSet {
    let rawValue: Int

    static let carbs            = AlgorithmEffectsOptions(rawValue: 1 << 0)
    static let insulin          = AlgorithmEffectsOptions(rawValue: 1 << 1)
    static let momentum         = AlgorithmEffectsOptions(rawValue: 1 << 2)
    static let retrospection    = AlgorithmEffectsOptions(rawValue: 1 << 3)

    static let all: AlgorithmEffectsOptions = [.carbs, .insulin, .momentum, .retrospection]
}

struct AlgorithmEffectsTimeline {
    let summaries: [AlgorithmEffectSummary]
}

struct LoopPrediction: GlucosePrediction {
    var glucose: [PredictedGlucoseValue]
    var effects: LoopAlgorithmEffects
}

actor LoopAlgorithm {

    typealias InputType = LoopPredictionInput
    typealias OutputType = LoopPrediction

    private static var treatmentHistoryInterval: TimeInterval = .hours(24)

    static func treatmentHistoryDateInterval(for startDate: Date) -> DateInterval {
        return DateInterval(
            start: startDate.addingTimeInterval(-LoopAlgorithm.treatmentHistoryInterval).dateFlooredToTimeInterval(.minutes(5)),
            end: startDate)
    }

    static func glucoseHistoryDateInterval(for startDate: Date) -> DateInterval {
        return DateInterval(
            start: startDate.addingTimeInterval(insulinActivityDuration-LoopAlgorithm.treatmentHistoryInterval),
            end: startDate)
    }

    static var insulinActivityDuration: TimeInterval = TimeInterval(hours: 6) + TimeInterval(minutes: 10)

    static var momentumDataInterval: TimeInterval = .minutes(15)

    // Generates a forecast predicting glucose.
    static func getForecast(input: LoopPredictionInput, startDate: Date? = nil) throws -> LoopPrediction {

        guard let latestGlucose = input.glucoseHistory.last else {
            throw AlgorithmError.missingGlucose
        }

        let start = startDate ?? latestGlucose.startDate

        let insulinModelProvider = PresetInsulinModelProvider(defaultRapidActingModel: nil)

        let effectsInterval = DateInterval(
            start: Self.treatmentHistoryDateInterval(for: start).start,
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

        // Try calculating insulin effects at glucose sample timestamps. This should produce more accurate samples to compare against glucose.
//        let effectDates = input.glucoseHistory.map { $0.startDate }
//        let insulinEffectsAtGlucoseTimestamps = annotatedDoses.glucoseEffects(
//            insulinModelProvider: insulinModelProvider,
//            longestEffectDuration: input.insulinActivityDuration,
//            insulinSensitivityTimeline: input.sensitivity,
//            effectDates: effectDates)

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

        var effects = [[GlucoseEffect]]()

        if input.algorithmEffectsOptions.contains(.carbs) {
            effects.append(carbEffects)
        }

        if input.algorithmEffectsOptions.contains(.insulin) {
            effects.append(insulinEffects)
        }

        if input.algorithmEffectsOptions.contains(.retrospection) {
            effects.append(rcEffect)
        }

        // Glucose Momentum
        let momentumEffects: [GlucoseEffect]
        if input.algorithmEffectsOptions.contains(.momentum) {
            let momentumInputData = input.glucoseHistory.filterDateRange(start.addingTimeInterval(-momentumDataInterval), start)
            momentumEffects = momentumInputData.linearMomentumEffect()
        } else {
            momentumEffects = []
        }

        let prediction = LoopMath.predictGlucose(startingAt: latestGlucose, momentum: momentumEffects, effects: effects)

//        print("**********")
//        print("carbEffects = \(carbEffects)")
//        print("retrospectiveGlucoseDiscrepancies = \(retrospectiveGlucoseDiscrepancies)")
//        print("rc = \(rcEffect)")

        return LoopPrediction(
            glucose: prediction,
            effects: LoopAlgorithmEffects(
                insulin: insulinEffects,
                carbs: carbEffects,
                retrospectiveCorrection: rcEffect,
                momentum: momentumEffects,
                insulinCounteraction: insulinCounteractionEffects
            )
        )
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


