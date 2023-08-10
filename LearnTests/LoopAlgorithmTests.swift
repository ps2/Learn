//
//  LoopAlgorithmTests.swift
//  LearnTests
//
//  Created by Pete Schwamb on 7/29/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit
@testable import Learn

final class LoopAlgorithmTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testHighAndStable() {
//        let input = LoopAlgorithmInput(
//            glucoseHistory: [
//                StoredGlucoseSample(startDate: <#T##Date#>, quantity: <#T##HKQuantity#>)
//            ],
//            doses: <#T##[DoseEntry]#>,
//            carbEntries: <#T##[CarbEntry]#>,
//            basal: <#T##[AbsoluteScheduleValue<Double>]#>,
//            sensitivity: <#T##[AbsoluteScheduleValue<HKQuantity>]#>,
//            carbRatio: <#T##[AbsoluteScheduleValue<Double>]#>,
//            target: <#T##[AbsoluteScheduleValue<ClosedRange<HKQuantity>>]#>)
//
//        setUp(for: .highAndStable)
//        let predictedGlucoseOutput = loadGlucoseEffect("high_and_stable_predicted_glucose")
//
//        let updateGroup = DispatchGroup()
//        updateGroup.enter()
//        var predictedGlucose: [PredictedGlucoseValue]?
//        var recommendedBasal: TempBasalRecommendation?
//        self.loopDataManager.getLoopState { _, state in
//            predictedGlucose = state.predictedGlucose
//            recommendedBasal = state.recommendedAutomaticDose?.recommendation.basalAdjustment
//            updateGroup.leave()
//        }
//        // We need to wait until the task completes to get outputs
//        updateGroup.wait()
//
//        XCTAssertNotNil(predictedGlucose)
//        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
//
//        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
//            XCTAssertEqual(expected.startDate, calculated.startDate)
//            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
//        }
//
//        XCTAssertEqual(4.63, recommendedBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }
}
