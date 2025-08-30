//
//  QuantityLabel.swift
//  Learn
//
//  Created by Pete Schwamb on 10/13/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit
import LoopAlgorithm

struct QuantityLabel: View {
    var name: LocalizedStringKey
    var value: LoopQuantity?
    var formatter: QuantityFormatter

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            if let value, let valueStr = formatter.string(from: value) {
                Text(valueStr)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    QuantityLabel(
        name: "Glucose",
        value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 70),
        formatter: QuantityFormatter(for: .milligramsPerDeciliter))
    .padding()
}
