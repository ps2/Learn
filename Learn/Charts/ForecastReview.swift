//
//  ForecastReview.swift
//  Learn
//
//  Created by Pete Schwamb on 7/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import HealthKit
import LoopKit

struct ForecastReview: View {

    private var dataSource: any DataSource


    @EnvironmentObject private var formatters: QuantityFormatters

    @State private var baseTime: Date

    @State private var algorithmInput: AlgorithmInput?
    @State private var algorithmOutput: AlgorithmOutput?

    var fullInterval: DateInterval {
        DateInterval(
            start: self.baseTime.addingTimeInterval(-LoopAlgorithm.insulinActivityDuration).dateFlooredToTimeInterval(.minutes(5)),
            end: self.baseTime.addingTimeInterval(LoopAlgorithm.insulinActivityDuration).dateCeiledToTimeInterval(.minutes(5))
        )
    }

    init(dataSource: any DataSource, initialBaseTime: Date? = nil)  {
        self.dataSource = dataSource
        self._baseTime = State(initialValue: initialBaseTime ?? dataSource.endOfData ?? Date())
    }

    func generateForecast() async {
        let historyInterval = DateInterval(
            start: baseTime.addingTimeInterval(-LoopAlgorithm.insulinActivityDuration).dateFlooredToTimeInterval(.minutes(5)),
            end: baseTime)

        do {
            let glucose = try await dataSource.getGlucoseValues(interval: historyInterval).map { value in
                value as? StoredGlucoseSample ??
                StoredGlucoseSample(startDate: value.startDate, quantity: value.quantity)
            }
            let doses = try await dataSource.getDoses(interval: historyInterval)
            let carbEntries = try await dataSource.getCarbEntries(interval: historyInterval)

            // Doses can overlap history interval, so find the actual earliest time we'll need ISF coverage
            let isfStart = doses.map { $0.startDate }.min() ?? historyInterval.start

            let isfInterval = DateInterval(start: isfStart, end: fullInterval.end)


            algorithmInput = AlgorithmInput(
                glucoseHistory: glucose,
                doses: doses,
                carbEntries: carbEntries,
                basal: try await dataSource.getBasalHistory(interval: fullInterval),
                sensitivity: try await dataSource.getInsulinSensitivityHistory(interval: isfInterval),
                carbRatio: try await dataSource.getCarbRatioHistory(interval: fullInterval),
                target: try await dataSource.getTargetRangeHistory(interval: fullInterval))

            algorithmOutput = try LoopAlgorithm.getForecast(input: algorithmInput!)
        } catch {
            print("Could not create forecast: \(error)")
        }

    }

    var subTitle: String {
        if let algorithmOutput, let quantity = algorithmOutput.prediction.last?.quantity {
            return "Eventually " + formatters.glucoseFormatter.string(from: quantity)!
        } else {
            return ""
        }
    }


    var body: some View {
        ScrollView {
            Text("Forecast Details").bold()
            HStack {
                Spacer()
                Button {
                    baseTime -= .minutes(5)
                } label: {
                    Image(systemName: "arrow.left.circle")
                }
                DatePicker(
                    "Base Time",
                    selection: $baseTime
                )
                .datePickerStyle(.compact)
                Button {
                    baseTime += .minutes(5)
                } label: {
                    Image(systemName: "arrow.right.circle")
                }
                Spacer()
            }
            VStack(alignment: .leading) {
                if let algorithmInput, let algorithmOutput {
                    HStack {
                        Text("Glucose")
                        Spacer()
                        Text(subTitle)
                            .foregroundColor(.secondary)
                    }
                    glucoseChart(algorithmInput: algorithmInput, algorithmOutput: algorithmOutput)
                    Text("Insulin Counteraction")
                    glucoseEffectsChart(algorithmOutput.effects.insulinCounteraction, color: .gray)
                    Text("Carb Effects")
                    glucoseEffectsChart(algorithmOutput.effects.carbs.asVelocities(), color: .carbs)
                    Text("Insulin Effects")
                    glucoseEffectsChart(algorithmOutput.effects.insulin.asVelocities(), color: .insulin)
                    Text("Retrospective Correction Effects")
                    glucoseEffectsChart(algorithmOutput.effects.retrospectiveCorrection.asVelocities(), color: .insulin)
                }
            }
            .chartXScale(domain: fullInterval.start...fullInterval.end)
            .padding()
            .onAppear {
                Task {
                    await generateForecast()
                }
            }
            .onChange(of: baseTime) { newValue in
                Task {
                    await generateForecast()
                }
            }
        }
    }
    
    func glucoseChart(algorithmInput: AlgorithmInput, algorithmOutput: AlgorithmOutput) -> some View {
        Chart {
            ForEach(algorithmInput.glucoseHistory, id: \.startDate) { effect in
                PointMark(
                    x: .value("Time", effect.startDate),
                    y: .value("Historic Glucose", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .symbolSize(CGSize(width: 4, height: 4))
                .foregroundStyle(Color.glucose)

            }
            ForEach(algorithmOutput.prediction, id: \.startDate) { effect in
                LineMark(
                    x: .value("Time", effect.startDate),
                    y: .value("Current Effects", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [8,5]))
                .foregroundStyle(Color.glucose)
            }
        }
        .chartYScale(domain: 40...350)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 7)) { value in
                AxisGridLine()

                if let glucose: Double = value.as(Double.self) {
                    let quantity = HKQuantity(unit: formatters.glucoseUnit, doubleValue: glucose)
                    AxisValueLabel {
                        Text(formatters.glucoseFormatter.string(from: quantity, includeUnit: false)!)
                            .frame(width: 25, alignment: .trailing)
                    }
                }
            }
        }
    }

    func glucoseEffectsChart(_ effect: [GlucoseEffectVelocity], color: Color) -> some View {
        Chart {
            ForEach(effect, id: \.startDate) { effect in
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

struct ForecastReview_Previews: PreviewProvider {
    @State private var date: Date = Date()

    static var previews: some View {
        ForecastReview(dataSource: MockDataSource())
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
