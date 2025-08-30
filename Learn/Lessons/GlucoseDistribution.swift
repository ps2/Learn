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
import LoopKit
import LoopAlgorithm

struct GlucoseDistribution: View {
    @EnvironmentObject private var formatters: QuantityFormatters

    @State var asLogNormal: Bool = false

    let dataSource: any DataSource

    struct Bin {
        var value: Double
        var percent: Double
        var color: Color
    }

    @State var histogram: [Bin] = []
    @State var interval: DateInterval
    @State var mean: Double?
    @State var standardDeviation: Double?
    @State var error: Error?

    var limits: ClosedRange<Double> {
        let unit = formatters.glucoseUnit

        var limits: ClosedRange<Double>

        if unit == LoopUnit.milligramsPerDeciliter {
            limits = 40...400
        } else {
            limits = 2.2...22.2
        }

        if asLogNormal {
            limits = ClosedRange(uncheckedBounds: (
                lower: log(limits.lowerBound),
                upper: log(limits.upperBound)
            ))
        }

        return limits
    }

    init(dataSource: any DataSource, interval: DateInterval) {
        self.dataSource = dataSource
        self._interval = State(initialValue: interval)
    }

    func computeHistogram() async {
        let unit = formatters.glucoseUnit

        let binCount: Int = 37

        let limits = self.limits

        let binSize = (limits.upperBound - limits.lowerBound) / Double(binCount-1)

        do {
            let glucose = try await dataSource.getGlucoseValues(interval: interval)
            var samples: [Double]
            samples = glucose.map { $0.quantity.doubleValue(for: unit) }
            if asLogNormal {
                samples = samples.map { log($0) }
            }

            let sampleCount = samples.count
            var result: [Int] = Array(repeating: 0, count: binCount)
            for sample in samples {
                let bin = Int(((sample-limits.lowerBound)/binSize).rounded())
                result[bin] += 1
            }

            (mean, standardDeviation) = GlucoseMath.meanAndStandardDeviation(of: samples)!
            let target = TargetRange.standardRanges(for: unit)
            histogram = result.enumerated().map({ (index, count) in
                let value = Double(index) * binSize + limits.lowerBound

                var color = target.category(for: value).color

                if asLogNormal {
                    color = target.category(for: exp(value)).color
                }

                return Bin(
                    value: value,
                    percent: Double(count) / Double(sampleCount) * 100,
                    color: color
                )
            })
        } catch {
            self.error = error
        }
    }

    var body: some View {
        VStack {
            Text("Distribution of Glucose Values")
            Text("\(Int(interval.duration.days)) days of data included.")
            chart
            Toggle("Log Glucose Scale", isOn: $asLogNormal)
            if let mean, let standardDeviation {
                if asLogNormal {
                    Text("mean(log(glucose)) = \(mean)")
                    Text("exp(mean(log(glucose))) = \(exp(mean))")
                    Text("stddev(log(glucose)) = \(standardDeviation)")
                } else {
                    Text("mean(glucose) = \(mean)")
                    Text("log(mean(glucose)) = \(log(mean))")
                    Text("stddev(glucose) = \(standardDeviation)")
                }
            }
        }
        .onAppear(perform: {
            refresh()
        })
        .onChange(of: asLogNormal) { oldValue, newValue in
            refresh()
        }

    }

    func refresh() {
        Task {
            await computeHistogram()
        }
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
        .chartXScale(domain: limits)
    }
}

#Preview {
    GlucoseDistribution(dataSource: MockDataSource(), interval: .lastWeek)
        .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
        .padding()
}
