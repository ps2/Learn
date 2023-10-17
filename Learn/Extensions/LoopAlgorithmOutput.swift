//
//  LoopAlgorithmOutput.swift
//  Learn
//
//  Created by Pete Schwamb on 10/13/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

extension LoopAlgorithmOutput {
    var activeInsulinQuantity: HKQuantity {
        return HKQuantity(unit: .internationalUnit(), doubleValue: activeInsulin)
    }

    
}
