//
//  LoopDosingExample.swift
//  Learn
//
//  Created by Pete Schwamb on 7/13/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import HealthKit
import LoopKit
import LoopAlgorithm

struct LoopDosingExample: View {

    static func scenario(baseTime: Date) -> LoopPredictionInput<StoredCarbEntry, StoredGlucoseSample, DoseEntry> {
        func t(_ offset: TimeInterval) -> Date {
            return baseTime.addingTimeInterval(offset)
        }

        func glucose(_ date: Date, value: Double) -> StoredGlucoseSample {
            return StoredGlucoseSample(
                startDate: date,
                quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: value))
        }

        let glucoseHistory = [
            glucose(t(.minutes(-21)), value: 110),
            glucose(t(.minutes(-16)), value: 111),
            glucose(t(.minutes(-11)), value: 112),
            glucose(t(.minutes(-6)), value: 118),
            glucose(t(.minutes(-1)), value: 130)
        ]

        let dose = DoseEntry(
            type: .bolus,
            startDate: t(
                .hours(-1)
            ),
            value: 1.0,
            unit: .units,
            decisionId: nil
        )

        let sensitivity = [
            AbsoluteScheduleValue(startDate: t(.hours(-7)), endDate: t(.hours(7)), value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 50))
        ]

        let carbRatio = [
            AbsoluteScheduleValue(startDate: t(.hours(-7)), endDate: t(.hours(7)), value: 10.0)
        ]

        let basal = [
            AbsoluteScheduleValue(startDate: t(.hours(-7)), endDate: t(.hours(7)), value: 1.0)
        ]

        return LoopPredictionInput(
            glucoseHistory: glucoseHistory,
            doses: [dose],
            carbEntries: [],
            basal: basal,
            sensitivity: sensitivity,
            carbRatio: carbRatio,
            algorithmEffectsOptions: .all,
            useIntegralRetrospectiveCorrection: false,
            includePositiveVelocityAndRC: true
        )
    }

    @EnvironmentObject private var formatters: QuantityFormatters

    private var baseTime: Date = Date(timeIntervalSinceReferenceDate: 0)

    private var algorithmInput: LoopPredictionInput<StoredCarbEntry, StoredGlucoseSample, DoseEntry>
    @State private var algorithmOutput: LoopPrediction<StoredCarbEntry>?

    init()  {
        algorithmInput = Self.scenario(baseTime: baseTime)
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
            if let algorithmOutput {
                chart(algorithmOutput: algorithmOutput)
            }
        }
        .padding()
        .onAppear {
            algorithmOutput = LoopAlgorithm.generatePrediction(input: algorithmInput)
        }
    }

    func chart(algorithmOutput: LoopPrediction<StoredCarbEntry>) -> some View {
        Chart {
            ForEach(algorithmInput.glucoseHistory, id: \.startDate) { effect in
                PointMark(
                    x: .value("Time", effect.startDate.timeIntervalSince(baseTime).hours),
                    y: .value("Historic Glucose", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .symbolSize(CGSize(width: 6, height: 6))
                .foregroundStyle(Color.glucose)

            }
            ForEach(algorithmOutput.glucose, id: \.startDate) { effect in
                LineMark(
                    x: .value("Time", effect.startDate.timeIntervalSince(baseTime).hours),
                    y: .value("Current Effects", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [8,5]))
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
                    let quantity = LoopQuantity(unit: formatters.glucoseUnit, doubleValue: glucose)
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
