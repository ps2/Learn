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

    var predictedInsulinEffect: HKQuantity? {
        guard let last = effects.insulin.last?.quantity, let first = effects.insulin.first?.quantity else {
            return nil
        }
        let change = last.doubleValue(for: .milligramsPerDeciliter) - first.doubleValue(for: .milligramsPerDeciliter)
        return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: change)
    }

    var predictedCarbEffect: HKQuantity? {
        guard let last = effects.carbs.last?.quantity, let first = effects.carbs.first?.quantity else {
            return nil
        }
        let change = last.doubleValue(for: .milligramsPerDeciliter) - first.doubleValue(for: .milligramsPerDeciliter)
        return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: change)
    }

    var predictedRetrospectiveCorrectionEffect: HKQuantity? {
        guard let last = effects.retrospectiveCorrection.last?.quantity, let first = effects.retrospectiveCorrection.first?.quantity else {
            return nil
        }
        let change = last.doubleValue(for: .milligramsPerDeciliter) - first.doubleValue(for: .milligramsPerDeciliter)
        return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: change)
    }

}
