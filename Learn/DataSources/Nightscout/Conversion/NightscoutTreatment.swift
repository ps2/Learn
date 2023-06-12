//
//  NightscoutTreatment.swift
//  Learn
//
//  Created by Pete Schwamb on 6/10/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import NightscoutKit
import LoopKit

extension NightscoutTreatment {
    var carbs: CarbEntry? {
        switch self {
        case _ as CarbCorrectionNightscoutTreatment:
            print("Carbs!")
            return nil
        default:
            return nil
        }
    }

    var dose: DoseEntry? {
        if syncIdentifier == "74656d70426173616c20302e30373520323032332d30362d31315431373a30303a33375a" {
            print("Here")
        }
        switch self {
        case let tempBasal as TempBasalNightscoutTreatment:
            return DoseEntry(
                type: .tempBasal,
                startDate: tempBasal.timestamp,
                endDate: tempBasal.timestamp.addingTimeInterval(tempBasal.duration),
                value: tempBasal.rate,
                unit: .unitsPerHour,
                deliveredUnits: tempBasal.amount,
                syncIdentifier: tempBasal.syncIdentifier
            )
        case let bolus as BolusNightscoutTreatment:
            return DoseEntry(
                type: .bolus,
                startDate: bolus.timestamp,
                endDate: bolus.timestamp.addingTimeInterval(bolus.duration),
                value: bolus.programmed,
                unit: .unitsPerHour,
                deliveredUnits: bolus.amount,
                syncIdentifier: bolus.syncIdentifier
            )
        case _ as CarbCorrectionNightscoutTreatment:
            return nil // ignore
        default:
            print("Converting \(self)")
            return nil
        }
    }
}
