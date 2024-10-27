//
//  LearnTests.swift
//  LearnTests
//
//  Created by Pete Schwamb on 7/29/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit
@testable import Learn

final class LearnTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDoseSplitting() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZZZZZ"

        let f = { (input) in
            return formatter.date(from: input)!
        }

        let start = f("2018-08-16 01:07:00 +0000")

        let dose = DoseEntry(type: .tempBasal, startDate: start, endDate: start.addingTimeInterval(.minutes(15)), value: 8, unit: .unitsPerHour, deliveredUnits: 2)

        let segments = dose.splitIntoSimulationTimelineDeliverySegments()

        XCTAssertEqual(4, segments.count)

        let expectedRates = [4.8, 8, 8, 3.2]
        for (expected, computed) in zip(expectedRates, segments.map { $0.rate }) {
            XCTAssertEqual(expected, computed, accuracy: 0.01)
        }

    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
