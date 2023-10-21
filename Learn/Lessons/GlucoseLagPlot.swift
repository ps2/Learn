//
//  GlucoseLagPlot.swift
//  Learn
//
//  Created by Pete Schwamb on 10/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import HealthKit
import Charts

struct GlucoseLagPlot: View {
    @EnvironmentObject private var formatters: QuantityFormatters

    let dataSource: any DataSource

    struct Comparison {
        var date: Date
        var value: Double
        var previousValue: Double
    }

    @State var values: [Comparison] = []
    @State var interval: DateInterval
    @State var error: Error?

    func fetchData() async {
        let unit = formatters.glucoseUnit

        do {
            let glucose = try await dataSource.getGlucoseValues(interval: interval)
            values = glucose.enumerated().compactMap { (enumeration) -> Comparison? in
                let (index, sample) = enumeration
                guard index > 0 else {
                    return nil
                }
                let prev = glucose[index-1]
                guard sample.startDate.timeIntervalSince(prev.startDate) < .minutes(10) else {
                    return nil
                }
                return Comparison(
                    date: sample.startDate,
                    value: sample.quantity.doubleValue(for: unit),
                    previousValue: prev.quantity.doubleValue(for: unit))
            }
        } catch {
            self.error = error
        }
    }

    var body: some View {
        VStack {
            Text("This is a lag plot of glucose values. The x coordinate of a point is the glucose value of a given sample at a point in time, and the y coordinate is the glucose value of the sample preceeding it.")
            Text("Clustering along the plot diagonal indicates a strong correlation, which would be expected for a normal set of CGM data.")
            chart
        }
        .onAppear(perform: {
            refresh()
        })
    }

    private func refresh() {
        Task {
            await fetchData()
        }
    }

    private var chart: some View {
        Chart(values, id: \.date) {
            PointMark(
                x: .value("Value", $0.value),
                y: .value("Previous Value", $0.previousValue)
            )
        }
    }
}

#Preview {
    GlucoseLagPlot(dataSource: MockDataSource(), interval: .lastWeek)
        .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
}
