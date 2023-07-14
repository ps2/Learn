//
//  LoopDosingExample.swift
//  Learn
//
//  Created by Pete Schwamb on 7/13/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

import SwiftUI
import Charts
import HealthKit
import LoopKit

struct LoopDosingExample: View {

    @EnvironmentObject private var formatters: QuantityFormatters

    private var baseTime: Date = Date(timeIntervalSinceReferenceDate: 0)

    var effects: [GlucoseEffect]
    var effectsWithInflection: [GlucoseEffect]

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
        let dose = DoseEntry(type: .bolus, startDate: baseTime, value: 1.0, unit: .units)

        let schedule = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [RepeatingScheduleValue(startTime: 0, value: 50),
                         RepeatingScheduleValue(startTime: 3600*2, value: 75)],
            timeZone: TimeZone(secondsFromGMT: 0))!

        effects = []
        effects = [dose].glucoseEffects(
            insulinModelProvider:  PresetInsulinModelProvider(defaultRapidActingModel: nil),
            longestEffectDuration: .hours(6), insulinSensitivity: schedule)

        let changeTime = baseTime.addingTimeInterval(.hours(2))
        let endTime = baseTime.addingTimeInterval(.hours(6))

        let timeline = [
            AbsoluteScheduleValue(startDate: baseTime, endDate: changeTime, value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 50)),
            AbsoluteScheduleValue(startDate: changeTime, endDate: endTime, value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 75))
        ]
        effectsWithInflection = []
        effectsWithInflection = [dose].glucoseEffects(
            insulinModelProvider: PresetInsulinModelProvider(defaultRapidActingModel: nil),
            longestEffectDuration: .hours(6),
            insulinSensitivityTimeline: timeline)

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
                        Text("ISF changes from 50 to 75 mg/dL/U")
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

struct LoopDosingExample_Previews: PreviewProvider {
    static var previews: some View {
        LoopDosingExample()
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
