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

    static func scenario(baseTime: Date) -> AlgorithmInput {
        func t(_ offset: TimeInterval) -> Date {
            return baseTime.addingTimeInterval(offset)
        }

        func glucose(_ date: Date, value: Double) -> StoredGlucoseSample {
            return StoredGlucoseSample(
                startDate: date,
                quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value))
        }

        let glucoseHistory = [
            glucose(t(.minutes(-21)), value: 110),
            glucose(t(.minutes(-16)), value: 115),
            glucose(t(.minutes(-11)), value: 112),
            glucose(t(.minutes(-6)), value: 118),
            glucose(t(.minutes(-1)), value: 120)
        ]

        let dose = DoseEntry(type: .bolus, startDate: t(.hours(-1)), value: 1.0, unit: .units)

        let sensitivity = [
            AbsoluteScheduleValue(startDate: t(.hours(-7)), endDate: t(.hours(7)), value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 50))
        ]

        let carbRatio = [
            AbsoluteScheduleValue(startDate: t(.hours(-7)), endDate: t(.hours(7)), value: 10.0)
        ]

        let basal = [
            AbsoluteScheduleValue(startDate: t(.hours(-7)), endDate: t(.hours(7)), value: 1.0)
        ]

        let target = [
            AbsoluteScheduleValue(
                startDate: t(.hours(-7)),
                endDate: t(.hours(7)),
                value: ClosedRange(
                    uncheckedBounds: (
                        lower: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 100),
                        upper: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 110))
                )
            )
        ]

        return AlgorithmInput(
            glucoseHistory: glucoseHistory,
            doses: [dose],
            carbEntries: [],
            basal: basal,
            sensitivity: sensitivity,
            carbRatio: carbRatio,
            target: target)
    }

    @EnvironmentObject private var formatters: QuantityFormatters

    private var baseTime: Date = Date(timeIntervalSinceReferenceDate: 0)

    private var algorithmInput: AlgorithmInput
    private var forecast: Forecast?

    init()  {

        algorithmInput = Self.scenario(baseTime: baseTime)

        do {
            forecast = try LoopAlgorithm.getForecast(input: algorithmInput)
        } catch {
            print("Could not create forecast: \(error)")
        }
    }

    var body: some View {
        VStack {
            HStack {
                Text("1 U Bolus").bold()
                Spacer()
                Text("Glucose Effects")
                    .foregroundColor(.secondary)
            }
            if let forecast {
                chart(forecast: forecast)
            }
        }
        .padding()
    }

    func chart(forecast: Forecast) -> some View {
        Chart {
            ForEach(algorithmInput.glucoseHistory, id: \.startDate) { effect in
                PointMark(
                    x: .value("Time", effect.startDate.timeIntervalSince(baseTime).hours),
                    y: .value("Current Effects", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .symbolSize(CGSize(width: 7, height: 7))
                .opacity(0.6)
            }
            ForEach(forecast.predicted, id: \.startDate) { effect in
                PointMark(
                    x: .value("Time", effect.startDate.timeIntervalSince(baseTime).hours),
                    y: .value("Current Effects", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .symbolSize(CGSize(width: 7, height: 7))
                .opacity(0.6)
            }
        }
        .chartXScale(domain: (-1.0)...6)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: [-1,0,1,2,3,4,5,6])
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
    }
}

struct LoopDosingExample_Previews: PreviewProvider {
    static var previews: some View {
        LoopDosingExample()
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
