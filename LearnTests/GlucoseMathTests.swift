//
//  GlucoseMathTests.swift
//  LearnTests
//
//  Created by Pete Schwamb on 10/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import XCTest

final class GlucoseMathTests: XCTestCase {

    func testResample() {
        let date = Date()
        let input = [
            GlucoseFixtureValue(date + .minutes( 1), mgdl: 100),
            GlucoseFixtureValue(date + .minutes( 7), mgdl: 110),
            GlucoseFixtureValue(date + .minutes(14), mgdl: 120),
            GlucoseFixtureValue(date + .minutes(19), mgdl: 130),
            GlucoseFixtureValue(date + .minutes(24), mgdl: 140),
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
