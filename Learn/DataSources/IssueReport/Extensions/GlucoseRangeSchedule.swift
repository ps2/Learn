//
//  GlucoseRangeSchedule.swift
//  Learn
//
//  Created by Pete Schwamb on 6/15/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopIssueReportParser
import LoopKit

extension LoopIssueReportParser.GlucoseRangeSchedule {

    // Convert parsed type into LoopKit type

    var loopKitRangeSchedule: LoopKit.GlucoseRangeSchedule? {
        let items = rangeSchedule.valueSchedule.items.map { item in
            let range = LoopKit.DoubleRange(minValue: item.value.minValue, maxValue: item.value.maxValue)
            return LoopKit.RepeatingScheduleValue(startTime: item.startTime, value: range)
        }

        return LoopKit.GlucoseRangeSchedule(
            unit: rangeSchedule.unit,
            dailyItems: items,
            timeZone: rangeSchedule.valueSchedule.timeZone)
    }
}
