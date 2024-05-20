//
//  InsulinMath.swift
//  Learn
//
//  Created by Pete Schwamb on 5/17/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopAlgorithm

extension Collection where Element: TimelineValue {
    public var timespan: DateInterval {

        guard count > 0 else {
            return DateInterval(start: Date(), duration: 0)
        }

        var min: Date = .distantFuture
        var max: Date = .distantPast
        for value in self {
            if value.startDate < min {
                min = value.startDate
            }
            if value.endDate > max {
                max = value.endDate
            }
        }
        return DateInterval(start: min, end: max)
    }
}
