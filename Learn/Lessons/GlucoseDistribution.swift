//
//  GlucoseDistribution.swift
//  Learn
//
//  Created by Pete Schwamb on 10/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import HealthKit

struct GlucoseDistribution: View {
    @EnvironmentObject private var formatters: QuantityFormatters

    let dataSource: any DataSource

    struct Bin {
        var value: Double
        var percent: Double
        var color: Color
    }

    @State var histogram: [Bin] = []
    @State var averageGlucose: HKQuantity?
    @State var interval: DateInterval
    @State var error: Error?

    func computeHistogram() async {
        let unit = formatters.glucoseUnit

        let binCount: Int
        let limits: ClosedRange<Double>

        if unit == HKUnit.milligramsPerDeciliter {
            binCount = 37
            limits = 40...400
        } else {
            binCount = 37
            limits = 2.2...22.2
        }

        let binSize = (limits.upperBound - limits.lowerBound) / Double(binCount-1)

        do {
            let glucose = try await dataSource.getGlucoseValues(interval: interval)
            let sampleCount = glucose.count
            var sum: Double = 0
            var result: [Int] = Array(repeating: 0, count: binCount)
            for sample in glucose {
                let sampleValue = sample.quantity.doubleValue(for: unit)
                sum += sampleValue
                let bin = Int(((sampleValue-limits.lowerBound)/binSize).rounded())
                result[bin] += 1
            }
            averageGlucose = HKQuantity(unit: unit, doubleValue: sum / Double(sampleCount))
            let target = TargetRange.standardRanges(for: unit)
            histogram = result.enumerated().map({ (index, count) in
                let value = Double(index) * binSize + limits.lowerBound
                return Bin(
                    value: value,
                    percent: Double(count) / Double(sampleCount) * 100,
                    color: target.category(for: value).color
                )
            })
        } catch {
            self.error = error
        }
    }

    var body: some View {
        VStack {
            if let averageGlucose {
                Text("Average Glucose: \(formatters.glucoseFormatter.string(from: averageGlucose)!)")
            }
            chart
        }
        .onAppear(perform: {
            Task {
                await computeHistogram()
            }
        })
    }

    private var chart: some View {
        Chart(histogram, id: \.value) {
            BarMark(
                x: .value("Glucose", $0.value),
                y: .value("Count", $0.percent),
                width: 6
            )
            .foregroundStyle($0.color)
        }
    }
}

#Preview {
    GlucoseDistribution(dataSource: MockDataSource(), interval: .lastWeek)
        .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
}
