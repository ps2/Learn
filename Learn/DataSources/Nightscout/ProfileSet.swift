//
//  ProfileSet.swift
//  Learn
//
//  Created by Pete Schwamb on 2/26/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import NightscoutKit
import LoopKit
import HealthKit

extension ProfileSet {
    var storedSettings: StoredSettings? {

        guard let profile = store["Default"],
              let glucoseSafetyLimit = settings.minimumBGGuard,
              let settingsGlucoseUnit = HKUnit.glucoseUnitFromNightscoutUnitString(units),
              let syncIdendifierUUID  = UUID(uuidString: syncIdentifier)
        else {
            return nil
        }

        // If units are specified on the schedule, prefer those over the units specified on the ProfileSet
        let scheduleGlucoseUnit: HKUnit
        if let profileUnitString = profile.units, let profileUnit = HKUnit.glucoseUnitFromNightscoutUnitString(profileUnitString)
        {
            scheduleGlucoseUnit = profileUnit
        } else {
            scheduleGlucoseUnit = settingsGlucoseUnit
        }

        let targetItems: [RepeatingScheduleValue<DoubleRange>] = zip(profile.targetLow, profile.targetHigh).map { (low,high) in
            return RepeatingScheduleValue(startTime: low.offset, value: DoubleRange(minValue: low.value, maxValue: high.value))
        }

        let targetRangeSchedule = GlucoseRangeSchedule(unit: scheduleGlucoseUnit, dailyItems: targetItems, timeZone: profile.timeZone)

        let correctionRangeOverrides: CorrectionRangeOverrides?
        if let range = settings.preMealTargetRange {
            correctionRangeOverrides = CorrectionRangeOverrides(
                preMeal: GlucoseRange(minValue: range.lowerBound, maxValue: range.upperBound, unit: settingsGlucoseUnit),
                workout: nil // No longer used
            )
        } else {
            correctionRangeOverrides = nil
        }

        let basalSchedule = BasalRateSchedule(
            dailyItems: profile.basal.map { RepeatingScheduleValue(startTime: $0.offset, value: $0.value) },
            timeZone: profile.timeZone)

        let sensitivitySchedule = InsulinSensitivitySchedule(
            unit: scheduleGlucoseUnit,
            dailyItems: profile.sensitivity.map { RepeatingScheduleValue(startTime: $0.offset, value: $0.value) },
            timeZone: profile.timeZone)

        let carbSchedule = CarbRatioSchedule(
            unit: .gram(),
            dailyItems: profile.carbratio.map { RepeatingScheduleValue(startTime: $0.offset, value: $0.value) },
            timeZone: profile.timeZone)

        return StoredSettings(
            date: startDate,
            dosingEnabled: settings.dosingEnabled,
            glucoseTargetRangeSchedule: targetRangeSchedule,
            preMealTargetRange: correctionRangeOverrides?.preMeal,
            overridePresets: settings.overridePresets.compactMap { $0.loopOverridePreset(for: settingsGlucoseUnit) },
            maximumBasalRatePerHour: settings.maximumBasalRatePerHour,
            maximumBolus: settings.maximumBolus,
            suspendThreshold: GlucoseThreshold(unit: settingsGlucoseUnit, value: glucoseSafetyLimit),
            basalRateSchedule: basalSchedule,
            insulinSensitivitySchedule: sensitivitySchedule,
            carbRatioSchedule: carbSchedule,
            automaticDosingStrategy: AutomaticDosingStrategy(nightscoutName: settings.dosingStrategy),
            syncIdentifier: syncIdendifierUUID)
    }
}
