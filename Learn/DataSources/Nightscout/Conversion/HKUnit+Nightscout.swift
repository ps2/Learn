//
//  LoopUnit.swift
//  Learn
//
//  Created by Pete Schwamb on 2/26/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopAlgorithm

extension LoopUnit {

    static func glucoseUnitFromNightscoutUnitString(_ unitString: String) -> LoopUnit? {
        // Some versions of Loop incorrectly uploaded units with
        // special characters to avoid line breaking.
        if unitString == LoopUnit.millimolesPerLiter.shortLocalizedUnitString() ||
            unitString == LoopUnit.millimolesPerLiter.shortLocalizedUnitString(avoidLineBreaking: false)
        {
            return .millimolesPerLiter
        }

        if unitString == LoopUnit.milligramsPerDeciliter.shortLocalizedUnitString() ||
            unitString == LoopUnit.milligramsPerDeciliter.shortLocalizedUnitString(avoidLineBreaking: false)
        {
            return .milligramsPerDeciliter
        }

        return nil
    }
}
