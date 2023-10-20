//
//  TargetRangeCategory.swift
//  Learn
//
//  Created by Pete Schwamb on 10/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI

enum TargetRangeCategory {
    case veryHigh
    case high
    case inRange
    case low
    case veryLow

    var color: Color {
        switch self {
        case .high, .veryHigh:
            return .highGlucose
        case .inRange:
            return .glucose
        case .low, .veryLow:
            return .lowGlucose
        }
    }

}
