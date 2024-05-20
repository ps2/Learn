//
//  KalmanSmoothedGlucose.swift
//  Learn
//
//  Created by Pete Schwamb on 10/23/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import Charts
import LoopKit

struct KalmanSmoothedGlucose: View {
    @EnvironmentObject private var formatters: QuantityFormatters

    let dataSource: any DataSource

    struct SmoothedSample {
        var date: Date
        var original: Double
        var smoothed: Double
    }

    @State var samples: [SmoothedSample] = []
    @State var interval: DateInterval
    @State var error: Error?

    func fetchAndCompute() async {
        do {
            let glucose = try await dataSource.getGlucoseValues(interval: interval)
            var filter = KalmanFilter(stateEstimatePrior: 1, errorCovariancePrior: 100)

            let processNoiseCovariance = 2.5
            let observationNoiseCovariance = 1.5

            samples = glucose.map { (sample) in
                let value = sample.quantity.doubleValue(for: .milligramsPerDeciliter)
                let prediction = filter.predict(stateTransitionModel: 1, controlInputModel: 0, controlVector: 0, covarianceOfProcessNoise: processNoiseCovariance)
                let update = prediction.update(measurement: value, observationModel: 1, covarienceOfObservationNoise: observationNoiseCovariance)
                filter = update
                return SmoothedSample(date: sample.startDate, original: value, smoothed: filter.stateEstimatePrior)
            }
        } catch {
            self.error = error
        }
    }

    var body: some View {
        VStack {
            Text("Kalman Smoothed Glucose")
            chart
        }
        .onAppear(perform: {
            Task {
                await fetchAndCompute()
            }
        })
    }

    private var chart: some View {
        Chart(samples, id: \.date) {
            PointMark(
                x: .value("Date", $0.date),
                y: .value("Original", $0.original)
            )
            LineMark(
                x: .value("Date", $0.date),
                y: .value("Smoothed", $0.smoothed)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: Double as Kalman input
extension Double: KalmanInput {
    public var transposed: Double { self }
    public var inversed: Double { 1 / self }
    public var additionToUnit: Double { 1 - self }
}


#Preview {
    KalmanSmoothedGlucose(dataSource: MockDataSource(), interval: .lastSixHours)
        .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
}
