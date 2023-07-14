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
    var predicted: [GlucoseValue]
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
    var delta: TimeInterval = TimeInterval(minutes: 5)
    var insulinActivityDuration: TimeInterval = TimeInterval(hours: 6) + TimeInterval(minutes: 10)
}

actor LoopAlgorithm {

    // Generates a forecast predicting glucose.
    func getForecast(input: AlgorithmInput, startDate: Date? = nil) -> Forecast {
        let start = startDate ?? input.glucoseHistory.last!.startDate

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
            insulinSensitivity: input.sensitivity)

        // Glucose Momentum
        // RC

        return Forecast(predicted: [])
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


