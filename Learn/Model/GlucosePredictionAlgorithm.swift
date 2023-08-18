//
//  GlucosePredictionAlgorithm.swift
//  Learn
//
//  Created by Pete Schwamb on 7/22/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

protocol GlucosePredictionInput {
    var glucoseHistory: [StoredGlucoseSample] { get }
    var doses: [DoseEntry] { get }
    var carbEntries: [CarbEntry] { get }
}

protocol GlucosePrediction {
    var glucose: [PredictedGlucoseValue] { get }
}

protocol GlucosePredictionAlgorithm {
    associatedtype InputType: GlucosePredictionInput
    associatedtype OutputType: GlucosePrediction

    static func treatmentHistoryDateInterval(for startDate: Date) -> DateInterval
    static func glucoseHistoryDateInterval(for startDate: Date) -> DateInterval

    static func getForecast(input: InputType, startDate: Date?) throws -> OutputType
}


extension LoopAlgorithm: GlucosePredictionAlgorithm {}
