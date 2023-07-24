//
//  GlucoseEffectChart.swift
//  Learn
//
//  Created by Pete Schwamb on 7/3/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import LoopKit
import HealthKit

struct GlucoseEffectChart: View {
    @EnvironmentObject private var formatters: QuantityFormatters

    private var glucoseEffects: [GlucoseEffectVelocity]
    private var color: Color

    init(_ effects: [GlucoseEffectVelocity], color: Color)  {
        self.glucoseEffects = effects
        self.color = color
    }

    var body: some View {
        Chart {
            ForEach(glucoseEffects, id: \.startDate) { effect in
                RectangleMark(
                    xStart: .value("Start Time", effect.startDate),
                    xEnd: .value("End Time", effect.endDate),
                    yStart: .value("Bottom", 0),
                    yEnd: .value("Value", effect.quantity.doubleValue(for: formatters.glucoseRateUnit))
                )
                .symbolSize(CGSize(width: 6, height: 6))
                .foregroundStyle(color)

            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 7)) { value in
                AxisGridLine()

                if let glucose: Double = value.as(Double.self) {
                    let quantity = HKQuantity(unit: formatters.glucoseRateUnit, doubleValue: glucose)
                    AxisValueLabel {
                        Text(formatters.glucoseRateFormatter.string(from: quantity, includeUnit: false)!)
                            .frame(width: 25, alignment: .trailing)
                    }
                }
            }
        }
    }
}

struct GlucoseEffectChart_Previews: PreviewProvider {
    static var previews: some View {

        let end = Date()
        let start = end.addingTimeInterval(-18 * 3600)
        let delta = TimeInterval(minutes: 5)
        let effect = stride(from: start, through: end, by: delta).map { date in
            let value = sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 5) / (3600*5) * Double.pi * 2) * 10
            let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value)
            return GlucoseEffectVelocity(startDate: start, endDate: start.addingTimeInterval(delta), quantity: quantity)
        }

        return GlucoseEffectChart(effect, color: .blue)
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
