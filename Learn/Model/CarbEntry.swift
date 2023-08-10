//
//  CarbEntry.swift
//  Learn
//
//  Created by Pete Schwamb on 7/29/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit

struct CarbEntry: Equatable, LoopKit.CarbEntry {
    var startDate: Date
    var absorptionTime: TimeInterval?
    var quantity: HKQuantity
}

extension CarbEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case startDate
        case absorptionTime
        case quantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startDate = try container.decode(Date.self, forKey: .startDate)
        absorptionTime = try container.decodeIfPresent(TimeInterval.self, forKey: .absorptionTime)

        let quantityValue = try container.decode(Double.self, forKey: .quantity)
        quantity = HKQuantity(unit: .gram(), doubleValue: quantityValue) // Assuming unit is grams; modify as needed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(absorptionTime, forKey: .absorptionTime)
        try container.encode(quantity.doubleValue(for: .gram()), forKey: .quantity) // Assuming unit is grams; modify as needed
    }
}
