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

    @State private var algorithmInput: LoopPredictionInput?
    @State private var algorithmOutput: LoopPrediction?

    var displayInterval: DateInterval {
        DateInterval(
            start: self.baseTime.addingTimeInterval(-InsulinMath.defaultInsulinActivityDuration).dateFlooredToTimeInterval(.minutes(5)),
            end: self.baseTime.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration).dateCeiledToTimeInterval(.minutes(5))
        )
    }

    init(dataSource: any DataSource, initialBaseTime: Date? = nil)  {
        self.dataSource = dataSource
        self._baseTime = State(initialValue: initialBaseTime ?? dataSource.endOfData ?? Date())
    }

    func generateForecast() async {
        do {
            let treatmentInterval = LoopAlgorithm.treatmentHistoryDateInterval(for: baseTime)
            let glucoseHistoryInterval = LoopAlgorithm.glucoseHistoryDateInterval(for: baseTime)

            let glucose = try await dataSource.getGlucoseValues(interval: glucoseHistoryInterval).map { value in
                value as? StoredGlucoseSample ??
                StoredGlucoseSample(startDate: value.startDate, quantity: value.quantity)
            }

            let doses = try await dataSource.getDoses(interval: treatmentInterval)
            let carbEntries = try await dataSource.getCarbEntries(interval: treatmentInterval)

            // Doses can overlap history interval, so find the actual earliest time we'll need ISF coverage
            let isfStart = min(treatmentInterval.start, doses.map { $0.startDate }.min() ?? .distantFuture) 
            let isfInterval = DateInterval(start: isfStart, end: displayInterval.end)

            let settings = LoopAlgorithmSettings(
                basal: try await dataSource.getBasalHistory(interval: treatmentInterval),
                sensitivity: try await dataSource.getInsulinSensitivityHistory(interval: isfInterval),
                carbRatio: try await dataSource.getCarbRatioHistory(interval: treatmentInterval),
                target: try await dataSource.getTargetRangeHistory(interval: displayInterval))

            algorithmInput = LoopPredictionInput(
                glucoseHistory: glucose,
                doses: doses,
                carbEntries: carbEntries,
                settings: settings)

            algorithmInput?.printFixture()

            algorithmOutput = try LoopAlgorithm.getForecast(input: algorithmInput!)
        } catch {
            print("Could not create forecast: \(error)")
        }

    }

    var subTitle: String {
        if let algorithmOutput, let quantity = algorithmOutput.glucose.last?.quantity {
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
                    Text("Insulin Effects")
                    GlucoseEffectChart(algorithmOutput.effects.insulin.asVelocities().filterDateInterval(interval: displayInterval), color: .insulin)
                    Text("Insulin Counteraction")
                    GlucoseEffectChart(algorithmOutput.effects.insulinCounteraction.filterDateInterval(interval: displayInterval), color: .gray)
                    Text("Carb Effects")
                    GlucoseEffectChart(algorithmOutput.effects.carbs.asVelocities().filterDateInterval(interval: displayInterval), color: .carbs)
                    Text("Retrospective Correction Effects")
                    GlucoseEffectChart(algorithmOutput.effects.retrospectiveCorrection.asVelocities(), color: .insulin)
                }
            }
            .timeXAxis()
            .chartXScale(domain: displayInterval.start...displayInterval.end)
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
    
    func glucoseChart(algorithmInput: GlucosePredictionInput, algorithmOutput: GlucosePrediction) -> some View {
        Chart {
            ForEach(algorithmInput.glucoseHistory.filterDateRange(displayInterval.start, displayInterval.end), id: \.startDate) { effect in
                PointMark(
                    x: .value("Time", effect.startDate),
                    y: .value("Historic Glucose", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .symbolSize(CGSize(width: 4, height: 4))
                .foregroundStyle(Color.glucose)

            }
            ForEach(algorithmOutput.glucose, id: \.startDate) { effect in
                LineMark(
                    x: .value("Time", effect.startDate),
                    y: .value("Current Effects", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [8,5]))
                .foregroundStyle(Color.glucose)
            }
            ForEach(algorithmInput.carbEntries.filterDateInterval(interval: displayInterval), id: \.startDate) { entry in
                PointMark(
                    x: .value("Time", entry.startDate, unit: .second),
                    y: 12
                )
                .symbol {
                    Image(systemName: "fork.knife.circle")
                        .foregroundColor(.carbs)
                }
                .annotation(position: .bottom, spacing: 0) {
                    Text(formatters.carbFormatter.string(from: entry.quantity)!)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
}

struct ForecastReview_Previews: PreviewProvider {
    @State private var date: Date = Date()

    static var previews: some View {
        ForecastReview(dataSource: MockDataSource())
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
