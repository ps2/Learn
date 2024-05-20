//
//  LoopChartsData.swift
//  Learn
//
//  Created by Pete Schwamb on 9/3/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit
import LoopAlgorithm

// Contains all the data for a Loop Charts display

struct LoopChartsData {
    var glucose: [StoredGlucoseSample] = []
    var targetRanges: [AbsoluteScheduleValue<ClosedRange<HKQuantity>>] = []
    var basalHistory: [AbsoluteScheduleValue<Double>] = []
    var doses: [DoseEntry] = []
    var manualBoluses: [DoseEntry] = []
    var carbEntries: [CarbEntry] = []
    var insulinOnBoard: [InsulinValue] = []
    var activeCarbs: [CarbValue] = []
}
