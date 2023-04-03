//
//  AutomaticDosingStrategy.swift
//  Learn
//
//  Created by Pete Schwamb on 2/26/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

extension AutomaticDosingStrategy {
    init(nightscoutName: String?) {
        switch nightscoutName {
        case "automaticBolus":
            self = .automaticBolus
        case "tempBasalOnly":
            self = .tempBasalOnly
        default:
            // If not set, assume tempBasalOnly
            self = .tempBasalOnly
        }
    }
}
