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

public struct AlgorithmEffectSummary {
    let date: Date

    let netInsulinEffect: HKQuantity
    let insulinOnBoard: Double // IU

    public init(date: Date, netInsulinEffect: HKQuantity, insulinOnBoard: Double) {
        self.date = date
        self.netInsulinEffect = netInsulinEffect
        self.insulinOnBoard = insulinOnBoard
    }
}

struct AlgorithmEffectsTimeline {
    let summaries: [AlgorithmEffectSummary]

    public init(summaries: [AlgorithmEffectSummary]) {
        self.summaries = summaries
    }
}

extension LoopAlgorithm {

    static func fetchLoopChartsData(dataSource: any DataSource, interval: DateInterval, now: Date? = nil) async throws -> LoopChartsData {
        await dataSource.syncData(interval: interval)
        var data = LoopChartsData()

        // Need to fetch doses back as far as t - (DIA + DCA) for Dynamic carbs
        let dosesInputHistory = CarbMath.maximumAbsorptionTimeInterval + InsulinMath.defaultInsulinActivityDuration
        let doseFetchInterval = DateInterval(
            start: interval.start.addingTimeInterval(-dosesInputHistory),
            end: interval.end)
        var historicDoses = try await dataSource.getDoses(interval: doseFetchInterval)


        let minDoseStart = historicDoses.map { $0.startDate }.min() ?? doseFetchInterval.start
        let historicBasal = try await dataSource.getBasalHistory(interval: DateInterval(start: minDoseStart, end: doseFetchInterval.end))
        let isfInterval = DateInterval(start: min(doseFetchInterval.start, minDoseStart), end: doseFetchInterval.end)
        let historicSensitivity = try await dataSource.getInsulinSensitivityHistory(interval: isfInterval)

        // Annotate with scheduled basal
        historicDoses = historicDoses.annotated(with: historicBasal)

        let insulinEffectsInterval = DateInterval(
            start: interval.start.addingTimeInterval(-CarbMath.maximumAbsorptionTimeInterval).dateFlooredToTimeInterval(GlucoseMath.defaultDelta),
            end: interval.end.dateCeiledToTimeInterval(GlucoseMath.defaultDelta))

        let insulinEffects = historicDoses.glucoseEffects(
            insulinSensitivityTimeline: historicSensitivity,
            from: insulinEffectsInterval.start,
            to: insulinEffectsInterval.end)

        // ICE
        let historicGlucose = try await dataSource.getGlucoseValues(interval: insulinEffectsInterval)
        let insulinCounteractionEffects = data.glucose.counteractionEffects(to: insulinEffects)

        // Carb Effects
        let carbInterval = DateInterval(
            start: interval.start.addingTimeInterval(-CarbMath.maximumAbsorptionTimeInterval).dateFlooredToTimeInterval(GlucoseMath.defaultDelta),
            end: interval.end.dateCeiledToTimeInterval(GlucoseMath.defaultDelta))
        let allCarbs = try await dataSource.getCarbEntries(interval: carbInterval)
        let carbRatio = try await dataSource.getCarbRatioHistory(interval: carbInterval)

        data.activeCarbs = allCarbs.map(
            to: insulinCounteractionEffects,
            carbRatio: carbRatio,
            insulinSensitivity: historicSensitivity
        ).dynamicCarbsOnBoard(from: interval.start, to: interval.end)

        // Output
        data.basalHistory = historicBasal.filterDateInterval(interval: interval)
        data.insulinOnBoard = historicDoses.insulinOnBoard()
        let viewableDoses = historicDoses.filterDateInterval(interval: interval)
        data.doses = viewableDoses.filter({ dose in
            dose.type != .bolus || dose.automatic == true
        })
        data.manualBoluses = viewableDoses.filter({ dose in
            dose.type == .bolus && dose.automatic != true
        })
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
                insulinSensitivityTimeline: sensitivityHistory,
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
