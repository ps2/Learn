//
//  ForecastScenario.swift
//  Learn
//
//  Created by Pete Schwamb on 6/29/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import HealthKit
import LoopKit

struct MidAbsorptionISFChange: View {

    @EnvironmentObject private var formatters: QuantityFormatters

    @State private var baseTime: Date = Date(timeIntervalSinceReferenceDate: 0)

    var effects: [GlucoseEffect]
    var effectsWithInflection: [GlucoseEffect]

    var endTime: Date {
        return baseTime.addingTimeInterval(.hours(6))
    }

    enum ForecastType: Plottable {
        var primitivePlottable: String {
            switch self {
            case .loopCurrent:
                return "Current"
            case .loopProposed:
                return "Proposed"
            }
        }

        init?(primitivePlottable: String) {
            return nil
        }

        typealias PrimitivePlottable = String

        case loopCurrent
        case loopProposed
    }

    init()  {
        let schedule = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [RepeatingScheduleValue(startTime: 0, value: 50),
                         RepeatingScheduleValue(startTime: 3600*2, value: 75)],
            timeZone: TimeZone(secondsFromGMT: 0))!

        effects = []
        effectsWithInflection = []
        let dose = DoseEntry(type: .bolus, startDate: baseTime, value: 1.0, unit: .units)
        effects = [dose].glucoseEffects(
            insulinModelProvider:  PresetInsulinModelProvider(defaultRapidActingModel: nil),
            longestEffectDuration: .hours(6), insulinSensitivity: schedule)

        effectsWithInflection = [dose].glucoseEffectsApplyingSensitivityChangesDuringDoseAbsorption(
            insulinModelProvider:  PresetInsulinModelProvider(defaultRapidActingModel: nil),
            longestEffectDuration: .hours(6), insulinSensitivity: schedule)

    }

    var body: some View {
        VStack {
            HStack {
                Text("1 U Bolus").bold()
                Spacer()
                Text("Glucose Effects")
                    .foregroundColor(.secondary)
            }
            Chart {
                RuleMark(x: .value("ISF Changed from 50 to 75 mg/dL/U", 2))
                    .annotation(position: .trailing, alignment: .top) {
                        Text("ISF schedule changes from 50 to 75 mg/dL/U")
                            .padding(5)
                            .foregroundColor(.secondary)
                    }
                    .foregroundStyle(Color.secondary)

                ForEach(effectsWithInflection, id: \.startDate) { effect in
                    PointMark(
                        x: .value("Time", effect.startDate.timeIntervalSince(baseTime).hours),
                        y: .value("Current Effects", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                    )
                    .foregroundStyle(by: .value("Forecast Type", ForecastType.loopProposed))
                    .symbol(by: .value("Forecast Type", ForecastType.loopProposed))
                    .symbolSize(CGSize(width: 7, height: 7))
                    .opacity(0.6)
                }
                ForEach(effects, id: \.startDate) { effect in
                    PointMark(
                        x: .value("Time", effect.startDate.timeIntervalSince(baseTime).hours),
                        y: .value("Current Effects", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                    )
                    .foregroundStyle(by: .value("Forecast Type", ForecastType.loopCurrent))
                    .symbol(by: .value("Forecast Type", ForecastType.loopCurrent))
                    .symbolSize(CGSize(width: 5, height: 5))
                    .opacity(0.6)
                }

            }
            .chartXScale(domain: 0...6)
            .chartXAxis {
                AxisMarks(preset: .aligned, values: [0,1,2,3,4,5,6])
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 7)) { value in
                    AxisGridLine()

                    if let glucose: Double = value.as(Double.self) {
                        let quantity = HKQuantity(unit: formatters.glucoseUnit, doubleValue: glucose)
                        AxisValueLabel(formatters.glucoseFormatter.string(from: quantity)!)
                    }
                }
            }
            .chartForegroundStyleScale([
                ForecastType.loopCurrent: .purple,
                ForecastType.loopProposed: .green
            ])
        }
        .padding()
    }
}


struct MidAbsorptionISFChange_Previews: PreviewProvider {
    static var previews: some View {
        MidAbsorptionISFChange()
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}

