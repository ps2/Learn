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

    private var baseTime: Date
    private var fullInterval: DateInterval

    @State private var algorithmInput: AlgorithmInput?
    @State private var algorithmOutput: AlgorithmOutput?

    init(dataSource: any DataSource)  {
        self.dataSource = dataSource
        self.baseTime = dataSource.endOfData ?? Date()
        fullInterval = DateInterval(
            start: baseTime.addingTimeInterval(-LoopAlgorithm.insulinActivityDuration).dateFlooredToTimeInterval(.minutes(5)),
            end: baseTime.addingTimeInterval(LoopAlgorithm.insulinActivityDuration).dateCeiledToTimeInterval(.minutes(5)))
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
        VStack(alignment: .leading) {
            HStack {
                Text("Loop Forecast").bold()
                Spacer()
                Text(subTitle)
                    .foregroundColor(.secondary)
            }
            if let algorithmInput, let algorithmOutput {
                glucoseChart(algorithmInput: algorithmInput, algorithmOutput: algorithmOutput)
                Text("Insulin Counteraction Effects")
                iceChart(algorithmInput: algorithmInput, algorithmOutput: algorithmOutput)
            }
        }
        .chartXScale(domain: fullInterval.start...fullInterval.end)
        .padding()
        .onAppear {
            Task {
                await generateForecast()
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
                .symbolSize(CGSize(width: 6, height: 6))
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
                        Text(formatters.glucoseFormatter.string(from: quantity)!)
                            .frame(width: 90, alignment: .trailing)
                    }
                }
            }
        }
    }

    func iceChart(algorithmInput: AlgorithmInput, algorithmOutput: AlgorithmOutput) -> some View {
        Chart {
            ForEach(algorithmOutput.effects.insulinCounteraction, id: \.startDate) { effect in
                RectangleMark(
                    xStart: .value("Start Time", effect.startDate),
                    xEnd: .value("End Time", effect.endDate),
                    yStart: .value("Bottom", 0),
                    yEnd: .value("Value", effect.quantity.doubleValue(for: formatters.glucoseRateUnit))
                )
                .symbolSize(CGSize(width: 6, height: 6))
                .foregroundStyle(Color.carbs)

            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 7)) { value in
                AxisGridLine()

                if let glucose: Double = value.as(Double.self) {
                    let quantity = HKQuantity(unit: formatters.glucoseRateUnit, doubleValue: glucose)
                    AxisValueLabel {
                        Text(formatters.glucoseRateFormatter.string(from: quantity)!)
                            .frame(width: 90, alignment: .trailing)
                    }
                }
            }
        }
    }

}

struct ForecastReview_Previews: PreviewProvider {
    static var previews: some View {
        ForecastReview(dataSource: MockDataSource())
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
