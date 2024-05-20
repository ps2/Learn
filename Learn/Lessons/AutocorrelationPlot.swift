//
//  AutocorrelationPlot.swift
//  Learn
//
//  Created by Pete Schwamb on 10/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import HealthKit
import Charts
import LoopKit
import LoopAlgorithm

struct AutocorrelationPlot: View {
    @EnvironmentObject private var formatters: QuantityFormatters

    let dataSource: any DataSource

    struct Correlation {
        var lag: TimeInterval
        var correlation: Double
    }

    @State var values: [Correlation] = []
    @State var interval: DateInterval
    @State var error: Error?

    func fetchAndCompute() async {
        do {
            let glucose = try await dataSource.getGlucoseValues(interval: interval)
            let delta = GlucoseMath.defaultDelta

            // To do autocorrelation, we need to have samples on a regular interval, and input glucose
            // is not guaranteed to be at regular intervals, so we need to resample.
            let start = interval.start.dateFlooredToTimeInterval(delta)

            let resampled = glucose.resampleNN(startDate: start, endDate: interval.end, delta: delta)

            // convert values into a normal distribution space (glucose is log normal)
            let resampled_logn = resampled.map { $0.map { log($0) } }

            // 288 lag offset = 24 hours
            let autocorr = GlucoseMath.autocorrelation(input: resampled_logn, maxLag: 288)

            values = autocorr.enumerated().compactMap({ (index, value) -> Correlation? in
                guard let value else {
                    return nil
                }
                let lag = delta * Double(index+1)
                return Correlation(
                    lag: lag,
                    correlation: value
                )
            })
        } catch {
            self.error = error
        }
    }

    var body: some View {
        VStack {
            Text("Autocorrelation plot of glucose values and their lagged counterparts.")
            chart
        }
        .onAppear(perform: {
            Task {
                await fetchAndCompute()
            }
        })
    }

    private var chart: some View {
        Chart(values, id: \.lag) {
            PointMark(
                x: .value("Lag", $0.lag.hours),
                y: .value("Correlation", $0.correlation)
            )
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: [0,3,6,9,12,15,18,21,24])
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

#Preview {
    AutocorrelationPlot(dataSource: MockDataSource(), interval: .lastMonth)
}
