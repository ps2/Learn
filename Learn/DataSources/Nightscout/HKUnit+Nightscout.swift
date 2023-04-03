//
//  HKUnit.swift
//  Learn
//
//  Created by Pete Schwamb on 2/26/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

extension HKUnit {

    static func glucoseUnitFromNightscoutUnitString(_ unitString: String) -> HKUnit? {
        // Some versions of Loop incorrectly uploaded units with
        // special characters to avoid line breaking.
        if unitString == HKUnit.millimolesPerLiter.shortLocalizedUnitString() ||
            unitString == HKUnit.millimolesPerLiter.shortLocalizedUnitString(avoidLineBreaking: false)
        {
            return .millimolesPerLiter
        }

        if unitString == HKUnit.milligramsPerDeciliter.shortLocalizedUnitString() ||
            unitString == HKUnit.milligramsPerDeciliter.shortLocalizedUnitString(avoidLineBreaking: false)
        {
            return .milligramsPerDeciliter
        }

        return nil
    }
}
