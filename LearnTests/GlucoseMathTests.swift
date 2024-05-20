//
//  GlucoseMathTests.swift
//  LearnTests
//
//  Created by Pete Schwamb on 10/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopAlgorithm
import HealthKit
@testable import Learn

final class GlucoseMathTests: XCTestCase {

    func testResample() {
        let date = Date()
        let input: [FixtureGlucoseSample] = [
            FixtureGlucoseSample(date + .minutes( 1), mgdl: 100),
            FixtureGlucoseSample(date + .minutes( 7), mgdl: 110),
            FixtureGlucoseSample(date + .minutes(14), mgdl: 120),
            FixtureGlucoseSample(date + .minutes(19), mgdl: 130),
            FixtureGlucoseSample(date + .minutes(24), mgdl: 140),
        ]

        let expected: [Double?] = [
            100, // 0
            110, // 5m
            110, // 10m
            120, // 15m
            130, // 20m
            140, // 25m
            nil
        ]

        XCTAssertEqual(expected, input.resampleNN(startDate: date, endDate: date + .minutes(30), delta: .minutes(5)))
    }
}

extension FixtureGlucoseSample {
    init(_ date: Date, mgdl: Double) {
        self.init(startDate: date, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: mgdl))
    }
}
