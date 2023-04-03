//
//  TemporaryScheduleOverride.swift
//  Learn
//
//  Created by Pete Schwamb on 2/26/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import NightscoutKit
import HealthKit
import LoopKit

extension NightscoutKit.TemporaryScheduleOverride  {

    func loopOverridePreset(for unit: HKUnit) -> LoopKit.TemporaryScheduleOverridePreset? {
        guard let name = name,
            let symbol = symbol
        else {
            return nil
        }

        let target: DoubleRange?
        if let lowerBound = targetRange?.lowerBound,
           let upperBound = targetRange?.upperBound
        {
            target = DoubleRange(minValue: lowerBound, maxValue: upperBound)
        } else {
            target = nil
        }

        let temporaryOverrideSettings = TemporaryScheduleOverrideSettings(
            unit: unit,
            targetRange: target,
            insulinNeedsScaleFactor: insulinNeedsScaleFactor)

        let loopDuration: LoopKit.TemporaryScheduleOverride.Duration

        if duration == 0 {
            loopDuration = .indefinite
        } else {
            loopDuration = .finite(duration)
        }

        return TemporaryScheduleOverridePreset(
            symbol: symbol,
            name: name,
            settings: temporaryOverrideSettings,
            duration: loopDuration)
    }
}
