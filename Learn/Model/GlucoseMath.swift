//
//  GlucoseMath.swift
//  Learn
//
//  Created by Pete Schwamb on 10/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit
import LoopAlgorithm

extension Collection where Element: GlucoseSampleValue, Index == Int {
    /// Resamples a timeline of glucose values to regular intervals specified by delta, using
    /// nearest neighbor and filling in with nil values where there the nearest neighbor is > delta.
    /// The receiver must be sorted in time ascending order.
    ///
    /// - Parameters:
    ///   - startDate: The starting date of the returned array
    ///   - delta: The time between returned samples
    ///   - unit: the unit to return interpolated values in. If nil, mg/dL is returned
    /// - Returns: An array of glucose values
    public func resampleNN(startDate: Date, endDate: Date, delta: TimeInterval = GlucoseMath.defaultDelta, unit: HKUnit? = nil) -> [Double?] {
        var result: [Double?] = []
        var dataIdx = 0
        var currentTimestamp = startDate

        while currentTimestamp <= endDate {
            // If we're beyond the last data point
            if dataIdx >= count {
                result.append(nil)
            } else {
                let dataPoint = self[dataIdx]

                // If sample timestamp is closer than the next one
                if dataIdx == count - 1 || abs(self[dataIdx + 1].startDate.timeIntervalSince(currentTimestamp)) > abs(dataPoint.startDate.timeIntervalSince(currentTimestamp)) {
                    if abs(dataPoint.startDate.timeIntervalSince(currentTimestamp)) <= delta {
                        result.append(dataPoint.quantity.doubleValue(for: unit ?? .milligramsPerDeciliter))
                    } else {
                        result.append(nil)
                    }
                } else {
                    dataIdx += 1
                    continue
                }
            }

            currentTimestamp += delta
        }

        return result
    }
}


extension GlucoseMath {
    static func autocorrelation(input: [Double?], maxLag: Int) -> [Double?] {
        let len = input.count
        var output: [Double?] = Array(repeating: nil, count: maxLag)
        for lag in 0..<maxLag {

            let x = input[0...(len-lag-1)]
            let y = input[lag...len-1]

            output[lag] = pearsonCorrelationCoefficient(x: x, y: y)
        }
        return output
    }

    static func pearsonCorrelationCoefficient(x: ArraySlice<Double?>, y: ArraySlice<Double?>) -> Double? {
        guard x.count == y.count else {
            // The two data sets must have the same size
            return nil
        }

        // Filter out pairs with nil values
        let filteredPairs: [(Double, Double)] = x.enumerated().compactMap { (index, xValue) in
            if let xVal = xValue, let yVal = y[y.startIndex + index] {
                return (xVal, yVal)
            }
            return nil
        }

        let n = Double(filteredPairs.count)
        guard n != 0 else { return nil }

        let sumX = filteredPairs.map { $0.0 }.reduce(0, +)
        let sumY = filteredPairs.map { $0.1 }.reduce(0, +)

        let sumX2 = filteredPairs.map { $0.0 * $0.0 }.reduce(0, +)
        let sumY2 = filteredPairs.map { $0.1 * $0.1 }.reduce(0, +)

        let sumXY = filteredPairs.map { $0.0 * $0.1 }.reduce(0, +)

        // Calculate Pearson correlation coefficient
        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

        if denominator == 0 {
            return nil
        }

        return numerator / denominator
    }

    static func meanAndStandardDeviation(of numbers: [Double]) -> (mean: Double, standardDeviation: Double)? {
        guard !numbers.isEmpty else { return nil }

        // Calculate the mean
        let mean = numbers.reduce(0, +) / Double(numbers.count)

        // Calculate the variance
        let variance = numbers.map { let d = ($0 - mean); return d*d }.reduce(0, +) / Double(numbers.count)

        // Standard Deviation is the square root of variance
        let standardDeviation = sqrt(variance)

        return (mean, standardDeviation)
    }
}
