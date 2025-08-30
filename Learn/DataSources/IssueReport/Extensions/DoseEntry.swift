//
//  DoseEntry.swift
//  Learn
//
//  Created by Pete Schwamb on 6/15/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

extension DoseEntry {
    static var mock: DoseEntry {
        DoseEntry(
            type: .bolus,
            startDate: Date(),
            endDate: Date(),
            value: 5,
            unit: .units,
            decisionId: nil,
            deliveredUnits: nil,
            description: nil,
            syncIdentifier: "503e0f3d031e447fa770c4e41d13a3e4",
            scheduledBasalRate: nil,
            insulinType: .novolog,
            automatic: true,
            manuallyEntered: false,
            isMutable: false,
            wasProgrammedByPumpUI: false)
    }

    // DoseEntry(type: LoopKit.DoseType.bolus, startDate: 2023-06-15 05:01:51 +0000, endDate: 2023-06-15 05:01:55 +0000, value: 0.1, unit: LoopKit.DoseUnit.units, deliveredUnits: nil, description: nil, insulinType: Optional(LoopKit.InsulinType.novolog), automatic: Optional(true), manuallyEntered: false, syncIdentifier: Optional("503e0f3d031e447fa770c4e41d13a3e4"), isMutable: false, wasProgrammedByPumpUI: false, scheduledBasalRate: nil)
}
