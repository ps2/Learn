//
//  QuantityFormatters.swift
//  Learn
//
//  Created by Pete Schwamb on 6/1/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

public class QuantityFormatters: ObservableObject {
    @Published public private(set) var glucoseUnit: HKUnit
    @Published public private(set) var glucoseFormatter: QuantityFormatter
    @Published public private(set) var glucoseRateFormatter: QuantityFormatter
    @Published public private(set) var insulinFormatter: QuantityFormatter
    @Published public private(set) var insulinRateFormatter: QuantityFormatter
    @Published public private(set) var carbFormatter: QuantityFormatter

    public init(glucoseUnit: HKUnit? = nil) {
        let configuredGlucoseUnit = glucoseUnit ?? .milligramsPerDeciliter
        self.glucoseUnit = configuredGlucoseUnit
        self.glucoseFormatter = QuantityFormatter(for: configuredGlucoseUnit)
        self.glucoseRateFormatter = QuantityFormatter(for: configuredGlucoseUnit.unitDivided(by: .minute()))
        self.insulinFormatter = QuantityFormatter(for: .internationalUnit())
        self.insulinRateFormatter = QuantityFormatter(for: .internationalUnitsPerHour)
        self.carbFormatter = QuantityFormatter(for: .gram())


        self.glucoseFormatter.numberFormatter.notANumberSymbol = "–"
        self.glucoseRateFormatter.numberFormatter.notANumberSymbol = "–"

        self.insulinFormatter.numberFormatter.maximumFractionDigits = 2
        self.insulinRateFormatter.numberFormatter.maximumFractionDigits = 2
    }

}
