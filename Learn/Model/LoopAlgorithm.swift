//
//  LoopAlgorithm.swift
//  Learn
//
//  Created by Pete Schwamb on 8/17/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit

extension LoopAlgorithm {

    static func fetchLoopChartsData(dataSource: any DataSource, interval: DateInterval, now: Date? = nil) async throws -> LoopChartsData {
        await dataSource.syncData(interval: interval)
        var data = LoopChartsData()

        // Need to fetch doses and glucose back as far as  t - (DIA + DCA) for
        // Dynamic carbs

        let dynamicCarbsDuration = InsulinMath.defaultInsulinActivityDuration + CarbMath.maximumAbsorptionTimeInterval

        let dynamicCarbsInterval = DateInterval(
            start: interval.start.addingTimeInterval(-dynamicCarbsDuration),
            end: interval.end)

        let historicGlucose = try await dataSource.getGlucoseValues(interval: dynamicCarbsInterval)
        var historicDoses = try await dataSource.getDoses(interval: dynamicCarbsInterval)
        let historicBasal = try await dataSource.getBasalHistory(interval: dynamicCarbsInterval)
        // Annotate with scheduled basal
        historicDoses = historicDoses.annotated(with: historicBasal)

        let historicSensitivity = try await dataSource.getInsulinSensitivityHistory(interval: dynamicCarbsInterval)

        let insulinEffects = historicDoses.glucoseEffects(
            insulinSensitivityTimeline: historicSensitivity,
            from: dynamicCarbsInterval.start,
            to: dynamicCarbsInterval.end
        )

        // ICE
        let insulinCounteractionEffects = data.glucose.counteractionEffects(to: insulinEffects)

        // Carb Effects
        let carbInterval = DateInterval(start: interval.start.addingTimeInterval(-CarbMath.maximumAbsorptionTimeInterval), end: interval.end)
        let allCarbs = try await dataSource.getCarbEntries(interval: carbInterval)
        //activeCarbs = allCarbs.dynamicCarbsOnBoard()

        let carbRatio = try await dataSource.getCarbRatioHistory(interval: carbInterval)

        data.activeCarbs = allCarbs.map(
            to: insulinCounteractionEffects,
            carbRatio: carbRatio,
            insulinSensitivity: historicSensitivity
        ).dynamicCarbsOnBoard()

        data.basalHistory = historicBasal.filterDateInterval(interval: interval)
        data.insulinOnBoard = historicDoses.insulinOnBoard()
        data.doses = historicDoses.filterDateInterval(interval: interval)
        data.carbEntries = allCarbs.filterDateInterval(interval: interval)
        data.targetRanges = try await dataSource.getTargetRangeHistory(interval: interval)
        data.glucose = historicGlucose.filterDateInterval(interval: interval)

        return data
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
