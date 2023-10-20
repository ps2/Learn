//
//  TargetRange.swift
//  Learn
//
//  Created by Pete Schwamb on 10/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

struct TargetRange {
    var low: Double
    var high: Double
    var veryLow: Double
    var veryHigh: Double

    static func standardRanges(for unit: HKUnit) -> TargetRange {
        if unit == .millimolesPerLiter {
            return TargetRange(
                low: 3.9,
                high: 10,
                veryLow: 3,
                veryHigh: 13.9)
        } else {
            return TargetRange(
                low: 70,
                high: 180,
                veryLow: 54,
                veryHigh: 250)
        }
    }

    func category(for value: Double) -> TargetRangeCategory {
        if value <= veryLow {
            return .veryLow
        } else if value <= low {
            return .low
        } else if value >= high {
            return .high
        } else if value >= veryHigh {
            return .veryHigh
        } else {
            return .inRange
        }
    }
}

