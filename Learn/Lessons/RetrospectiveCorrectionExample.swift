//
//  RetrospectiveCorrection.swift
//  Learn
//
//  Created by Pete Schwamb on 7/16/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import HealthKit
import LoopKit

struct RetrospectiveCorrectionExample: View {

    static func scenario(baseTime: Date) -> LoopPredictionInput {
        func t(_ offset: TimeInterval) -> Date {
            return baseTime.addingTimeInterval(offset)
        }

        func glucose(_ date: Date, value: Double) -> StoredGlucoseSample {
            return StoredGlucoseSample(
                startDate: date,
                quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value))
        }

        let glucoseHistory = [
            glucose(t(.minutes(-46)), value: 120),
            glucose(t(.minutes(-41)), value: 120),
            glucose(t(.minutes(-36)), value: 120),
            glucose(t(.minutes(-31)), value: 120),
            glucose(t(.minutes(-26)), value: 120),
            glucose(t(.minutes(-21)), value: 120),
            glucose(t(.minutes(-16)), value: 120),
            glucose(t(.minutes(-11)), value: 120),
            glucose(t(.minutes(-6)), value: 120),
            glucose(t(.minutes(-1)), value: 120)
        ]

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

        let dose = DoseEntry(type: .bolus, startDate: t(.hours(-2)), value: 1.0, unit: .units)

        // 0 temp basal for an hour
        //let dose = DoseEntry(type: .tempBasal, startDate: t(.hours(-2)), endDate: t(.hours(-1)), value: 0.0, unit: .units)
        //let carbEntry = StoredCarbEntry(startDate: t(.hours(-2)), quantity: HKQuantity(unit: .gram(), doubleValue: 15))

        let settings = LoopAlgorithmSettings(
            basal: basal,
            sensitivity: sensitivity,
            carbRatio: carbRatio,
            target: target)

        return LoopPredictionInput(
            glucoseHistory: glucoseHistory,
            doses: [dose],
            carbEntries: [],
            settings: settings)
    }

    @EnvironmentObject private var formatters: QuantityFormatters

    private var baseTime: Date = Date(timeIntervalSinceReferenceDate: 0)

    @State private var algorithmInput: LoopPredictionInput
    @State private var algorithmOutput: LoopPrediction?
    @State private var algorithmOutputWithoutRC: LoopPrediction?

    // construct a prediction of ICE + carbs
    @State private var exampleRCPrediction: [GlucoseEffect]?

    init()  {
        _algorithmInput = State(initialValue: Self.scenario(baseTime: baseTime))
    }

    var subTitle: String {
        if let algorithmOutput, let quantity = algorithmOutput.glucose.last?.quantity {
            return "Eventually " + formatters.glucoseFormatter.string(from: quantity)!
        } else {
            return ""
        }
    }

    var body: some View {
        VStack {
            HStack {
                Text("Loop Forecast").bold()
                Spacer()
                Text(subTitle)
                    .foregroundColor(.secondary)
            }
            if let algorithmOutput, let algorithmOutputWithoutRC {
                chart(algorithmOutput: algorithmOutput, algorithmOutputWithoutRC: algorithmOutputWithoutRC)
                Text("Eventually " + formatters.glucoseFormatter.string(from: algorithmOutput.glucose.last!.quantity)!)
                Text("Eventually Without RC " + formatters.glucoseFormatter.string(from: algorithmOutputWithoutRC.glucose.last!.quantity)!)
            }
            Spacer()

        }
        .padding()
        .onAppear {
            do {
                algorithmOutput = try LoopAlgorithm.getForecast(input: algorithmInput)
                algorithmInput.settings.algorithmEffectsOptions.remove(.retrospection)
                algorithmOutputWithoutRC = try LoopAlgorithm.getForecast(input: algorithmInput)
                exampleRCPrediction = algorithmOutput!.effects.insulinCounteraction.subtracting(algorithmOutput!.effects.carbs)
            } catch {
                print("Could not create forecast: \(error)")
            }
        }
    }

    func chart(algorithmOutput: GlucosePrediction, algorithmOutputWithoutRC: GlucosePrediction) -> some View {
        Chart {
            ForEach(algorithmInput.glucoseHistory, id: \.startDate) { effect in
                PointMark(
                    x: .value("Time", effect.startDate.timeIntervalSince(baseTime).hours),
                    y: .value("Historic Glucose", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .symbolSize(CGSize(width: 3, height: 3))
                .foregroundStyle(Color.glucose)

            }
            ForEach(algorithmOutput.glucose, id: \.startDate) { effect in
                LineMark(
                    x: .value("Time", effect.startDate.timeIntervalSince(baseTime).hours),
                    y: .value("Prediction", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .lineStyle(by: .value("Type", "Prediction"))
                .foregroundStyle(Color.glucose)
            }
            ForEach(algorithmOutputWithoutRC.glucose, id: \.startDate) { effect in
                LineMark(
                    x: .value("Time", effect.startDate.timeIntervalSince(baseTime).hours),
                    y: .value("Without RC", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .lineStyle(by: .value("Type", "Prediction Without RC"))
                .foregroundStyle(Color.glucose)
            }
        }
        .chartXScale(domain: (-1.0)...6.5)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: [-1,0,1,2,3,4,5,6])
        }
        .chartYScale(domain: 40...160)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 7)) { value in
                AxisGridLine()

                if let glucose: Double = value.as(Double.self) {
                    let quantity = HKQuantity(unit: formatters.glucoseUnit, doubleValue: glucose)
                    AxisValueLabel(formatters.glucoseFormatter.string(from: quantity)!)
                }
            }
        }
        .frame(maxHeight: 300)
    }
}

struct RetrospectiveCorrectionExample_Previews: PreviewProvider {
    static var previews: some View {
        RetrospectiveCorrectionExample()
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
