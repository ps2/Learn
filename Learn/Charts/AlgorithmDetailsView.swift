//
//  AlgorithmDetailsView.swift
//  Learn
//
//  Created by Pete Schwamb on 7/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import HealthKit
import LoopKit

struct AlgorithmDetailsView: View {

    private var dataSource: any DataSource

    @EnvironmentObject private var formatters: QuantityFormatters

    @State private var baseTime: Date

    @State private var algorithmInput: LoopAlgorithmInput?
    @State private var algorithmOutput: LoopAlgorithmOutput?

    @State private var algorithmError: AlgorithmError?

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
            // Need to fetch doses back as far as t - (DIA + DCA) for Dynamic carbs
            let dosesInputHistory = CarbMath.maximumAbsorptionTimeInterval + InsulinMath.defaultInsulinActivityDuration
            let doseFetchInterval = DateInterval(
                start: baseTime.addingTimeInterval(-dosesInputHistory),
                end: baseTime)
            let doses = try await dataSource.getDoses(interval: doseFetchInterval)

            let minDoseStart = doses.map { $0.startDate }.min() ?? doseFetchInterval.start
            let doseHistoryInterval = DateInterval(start: minDoseStart, end: doseFetchInterval.end)
            let basal = try await dataSource.getBasalHistory(interval: doseHistoryInterval)

            let forecastEndTime = baseTime.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration)

            // Include future carbs in query, but filter out ones entered after basetime.
            let carbHistoryInterval = DateInterval(
                start: baseTime.addingTimeInterval(-CarbMath.maximumAbsorptionTimeInterval),
                end: forecastEndTime)
            let carbEntries = try await dataSource.getCarbEntries(interval: carbHistoryInterval).filter {
                $0.userCreatedDate ?? $0.startDate < baseTime
            }

            let carbRatio = try await dataSource.getCarbRatioHistory(interval: carbHistoryInterval)

            let insulinEffectsInterval = DateInterval(
                start: carbHistoryInterval.start,
                end: baseTime
            )
            let glucose = try await dataSource.getGlucoseValues(interval: insulinEffectsInterval)

            let sensitivityInterval = DateInterval(
                start: min(carbHistoryInterval.start, doseHistoryInterval.start),
                end: forecastEndTime
            )
            let sensitivity = try await dataSource.getInsulinSensitivityHistory(interval: sensitivityInterval)

            let forecastInterval = DateInterval(
                start: baseTime,
                end: self.baseTime.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration).dateCeiledToTimeInterval(.minutes(5))
            )
            let target = try await dataSource.getTargetRangeHistory(interval: forecastInterval)

            let dosingSettings = try await dataSource.getDosingLimits(at: baseTime)

            guard let maxBolus = dosingSettings.maxBolus, let maxBasalRate = dosingSettings.maxBasalRate else {
                return
            }

            algorithmInput = LoopAlgorithmInput(
                predictionStart: baseTime,
                glucoseHistory: glucose,
                doses: doses,
                carbEntries: carbEntries,
                basal: basal,
                sensitivity: sensitivity,
                carbRatio: carbRatio,
                target: target,
                suspendThreshold: dosingSettings.suspendThreshold,
                maxBolus: maxBolus,
                maxBasalRate: maxBasalRate,
                useIntegralRetrospectiveCorrection: false,
                recommendationInsulinType: .novolog,
                recommendationType: .automaticBolus
            )

            algorithmInput?.printFixture()

            algorithmOutput = try LoopAlgorithm.run(input: algorithmInput!)

            print("*******************************************")
            algorithmOutput!.doseRecommendation.printFixture()

            algorithmError = nil
        } catch let error as AlgorithmError {
            algorithmError = error
            algorithmOutput = nil
            print("Could not create forecast: \(error)")
        } catch {
            preconditionFailure("Unexpected error: \(error)")
        }

    }

    var subTitle: String {
        if let algorithmOutput, let quantity = algorithmOutput.predictedGlucose.last?.quantity {
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
                    QuantityLabel(
                        name: "Starting Glucose",
                        value: algorithmInput.glucoseHistory.last?.quantity,
                        formatter: formatters.glucoseFormatter)
                    QuantityLabel(
                        name: "Eventual Glucose",
                        value: algorithmOutput.predictedGlucose.last?.quantity,
                        formatter: formatters.glucoseFormatter)
                    glucoseChart(algorithmInput: algorithmInput, predictedGlucose: algorithmOutput.predictedGlucose)
                    QuantityLabel(
                        name: "Insulin Effects",
                        value: algorithmOutput.effects.insulin.netEffect(after: baseTime)?.quantity,
                        formatter: formatters.glucoseFormatter)
                    GlucoseEffectChart(algorithmOutput.effects.insulin.asVelocities().filterDateInterval(interval: displayInterval), color: .insulin, yAxisWidth: 25)
                    QuantityLabel(
                        name: "Carb Effects",
                        value: algorithmOutput.effects.carbs.netEffect(after: baseTime)?.quantity,
                        formatter: formatters.glucoseFormatter)
                    GlucoseEffectChart(algorithmOutput.effects.carbs.asVelocities().filterDateInterval(interval: displayInterval), color: .carbs, yAxisWidth: 25)
                    QuantityLabel(
                        name: "Retrospective Correction Effects",
                        value: algorithmOutput.effects.retrospectiveCorrection.netEffect(after: baseTime)?.quantity,
                        formatter: formatters.glucoseFormatter)
                    GlucoseEffectChart(algorithmOutput.effects.retrospectiveCorrection.asVelocities(), color: .insulin, yAxisWidth: 25)
                    Text("Insulin Counteraction")
                    GlucoseEffectChart(algorithmOutput.effects.insulinCounteraction.filterDateInterval(interval: displayInterval), color: .gray, yAxisWidth: 25)
                    QuantityLabel(
                        name: "Momentum Effects",
                        value: algorithmOutput.effects.momentum.netEffect(after: baseTime)?.quantity,
                        formatter: formatters.glucoseFormatter)
                    GlucoseEffectChart(algorithmOutput.effects.momentum.asVelocities(), color: .glucose, yAxisWidth: 25)
                    QuantityLabel(
                        name: "Active Insulin",
                        value: algorithmOutput.activeInsulinQuantity,
                        formatter: formatters.insulinFormatter)
                    DoseRecommendationView(recommendation: algorithmOutput.doseRecommendation)

                }
                if let algorithmError {
                    Text("Algorithm Error: \(String(describing: algorithmError))")
                }
            }
            .dateTimeXAxis()
            .chartXScale(domain: displayInterval.start...displayInterval.end)
            .padding()
            .onAppear {
                Task {
                    await generateForecast()
                }
            }
            .onChange(of: baseTime) { oldValue, newValue in
                Task {
                    await generateForecast()
                }
            }
        }
    }
    
    func glucoseChart(algorithmInput: LoopAlgorithmInput, predictedGlucose: [PredictedGlucoseValue]) -> some View {
        Chart {
            ForEach(algorithmInput.glucoseHistory.filterDateRange(displayInterval.start, displayInterval.end), id: \.startDate) { effect in
                PointMark(
                    x: .value("Time", effect.startDate),
                    y: .value("Historic Glucose", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                )
                .symbolSize(CGSize(width: 4, height: 4))
                .foregroundStyle(Color.glucose)

            }
            ForEach(predictedGlucose, id: \.startDate) { effect in
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
        AlgorithmDetailsView(dataSource: MockDataSource())
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
