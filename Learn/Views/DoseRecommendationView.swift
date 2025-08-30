//
//  DoseRecommendationView.swift
//  Learn
//
//  Created by Pete Schwamb on 10/13/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit
import LoopAlgorithm

extension TempBasalRecommendation {
    var rateQuantity: LoopQuantity {
        return LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: unitsPerHour)
    }
}

struct TempBasalRecommendationView: View {
    @EnvironmentObject private var formatters: QuantityFormatters

    var recommendation: TempBasalRecommendation?

    var body: some View {
        if let recommendation {
            if recommendation.duration == 0 {
                Text("Cancel Temp Basal")
            } else {
                HStack {
                    Text("Temp Basal: ")
                    Text(formatters.insulinRateFormatter.string(from: recommendation.rateQuantity)!)
                }
            }
        } else {
            Text("No Temp Basal Change Recommended")
        }
    }
}

struct DoseRecommendationView: View {
    @EnvironmentObject private var formatters: QuantityFormatters
    
    var recommendation: LoopAlgorithmDoseRecommendation

    var body: some View {
        VStack {
            if let automaticRecommendation = recommendation.automatic {
                HStack {
                    Text("Automatic Bolus:")
                    Text(formatters.insulinFormatter.string(from: LoopQuantity(unit: .internationalUnit, doubleValue: automaticRecommendation.bolusUnits ?? 0))!)
                }
                TempBasalRecommendationView(recommendation: automaticRecommendation.basalAdjustment)
            }
            if let manualBolus = recommendation.manual {
                HStack {
                    Text("Manual Bolus:")
                    Text(formatters.insulinFormatter.string(from: manualBolus.quantity)!)
                }
            }
        }
    }
}

extension ManualBolusRecommendation {
    public var quantity: LoopQuantity { LoopQuantity(unit: .internationalUnit, doubleValue: amount) }
}

#Preview {
    DoseRecommendationView(recommendation: LoopAlgorithmDoseRecommendation(automatic: AutomaticDoseRecommendation(
                basalAdjustment: TempBasalRecommendation(unitsPerHour: 0, duration: 0),
                direction: .increase,
                bolusUnits: 0.5,
    )))
    .padding()
    .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
}
