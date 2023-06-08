//
//  GlucoseEntry.swift
//  Learn
//
//  Created by Pete Schwamb on 2/22/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import NightscoutKit
import LoopKit
import HealthKit

extension GlucoseEntry {
    var newGlucoseSample: NewGlucoseSample? {
        let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: glucose)

        guard let id else { return nil }

        let glucoseCondition: GlucoseCondition?
        switch condition {
        case .aboveRange:
            glucoseCondition = .aboveRange
        case .belowRange:
            glucoseCondition = .belowRange
        default:
            glucoseCondition = nil
        }

        let glucoseTrend: LoopKit.GlucoseTrend?
        if let rawTrend = trend?.rawValue {
            glucoseTrend = LoopKit.GlucoseTrend(rawValue: rawTrend)
        } else {
            glucoseTrend = nil
        }

        let trendRate: HKQuantity?
        if let changeRate {
            trendRate = HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: changeRate)
        } else {
            trendRate = nil
        }

        return NewGlucoseSample(
            date: date,
            quantity: quantity,
            condition: glucoseCondition,
            trend: glucoseTrend,
            trendRate: trendRate,
            isDisplayOnly: isCalibration ?? false,
            wasUserEntered: glucoseType == .meter,
            syncIdentifier: id)
    }

}
