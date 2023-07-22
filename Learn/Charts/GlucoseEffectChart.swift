//
//  GlucoseEffectChart.swift
//  Learn
//
//  Created by Pete Schwamb on 7/3/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import LoopKit
import HealthKit

struct GlucoseEffectChart: View {
    @EnvironmentObject private var formatters: QuantityFormatters
    @Environment(\.chartInspectionDate) private var chartInspectionDate

    @Binding var chartUnitOffset: Int
    private let numSegments: Int

    private let desiredYAxisNumberOfMarks: Int = 4

    private var yScale: ClosedRange<Double> {
        let min = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: yScaleMgDl.lowerBound)
        let max = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: yScaleMgDl.upperBound)
        return min.doubleValue(for: formatters.glucoseUnit)...max.doubleValue(for: formatters.glucoseUnit)
    }

    private var yScaleMgDl: ClosedRange<Double>
    private var xScale: ClosedRange<Date> { return startTime...endTime }

    private var startTime: Date
    private var endTime: Date
    private var upperRightLabel: String

    private var glucoseEffect: [GlucoseEffect]

    init(startTime: Date, endTime: Date, glucoseEffect: [GlucoseEffect], upperRightLabel: String, chartUnitOffset: Binding<Int>, numSegments: Int)  {

        self.startTime = startTime
        self.endTime = endTime
        self.glucoseEffect = glucoseEffect
        self.upperRightLabel = upperRightLabel
        self._chartUnitOffset = chartUnitOffset
        self.numSegments = numSegments

        let converted = glucoseEffect.map { $0.quantity.doubleValue(for: .milligramsPerDeciliter) }
        let max = converted.max()!
        let min = converted.min()!
        let range = max - min
        let margin = range * 0.2
        print("min = \(min), max = \(max), range = \(range), margin = \(margin)")
        self.yScaleMgDl = (min - margin)...(max + margin)
    }


    var yAxis: some View {
        Chart {
            PointMark(x: .value("Day", startTime, unit: .second), y: .value("Value", 0))
        }
        .chartYScale(domain: yScale)
        .foregroundStyle(.clear)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: desiredYAxisNumberOfMarks))
        }
        .frame(width:30, alignment: .trailing)
    }

    var body: some View {
        let inspectedElement = findElement(by: chartInspectionDate)
        VStack {
            HStack {
                Text("Glucose Effect").bold()
                Spacer()
                Text(upperRightLabel)
                    .foregroundColor(.secondary)
            }
            .opacity(inspectedElement == nil ? 1 : 0)

            ScrollableChart(yAxis: yAxis, chartUnitOffset: $chartUnitOffset, height: 250, numSegments: numSegments) {
                Chart {
                    ForEach(glucoseEffect, id: \.startDate) { effect in
                        AreaMark(
                            x: .value("Date", effect.startDate),
                            y: .value("Effect", effect.quantity.doubleValue(for: formatters.glucoseUnit))
                        )
                        .foregroundStyle(Color.glucose)
                        .opacity(0.5)
                    }
                    if let inspectedElement {
                        PointMark(
                            x: .value("Date", inspectedElement.startDate, unit: .second),
                            y: .value("Effect", inspectedElement.quantity.doubleValue(for: formatters.glucoseUnit))
                        )
                        .foregroundStyle(.secondary)
                        .symbolSize(CGSize(width: 15, height: 15))
                    }
                }
                .chartYScale(domain: yScale)
                .chartXScale(domain: xScale)
                .chartLongPressInspection()
                .chartOverlay { proxy in
                    Color.clear.anchorPreference(key: ChartInspectionAnchorPreferenceKey.self, value: .point(getSelectedPoint(selectedElement: inspectedElement, proxy: proxy))) { $0 }
                }
                .timeXAxis(labelOpacity: inspectedElement == nil ? 1 : 0)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: desiredYAxisNumberOfMarks)) {
                        AxisGridLine()
                    }
                }
            }
        }
        .overlayPreferenceValue(ChartInspectionAnchorPreferenceKey.self) { preferences in
            GeometryReader { geometry in
                preferences.map { anchor in
                    VStack {
                        if let selectedElement = inspectedElement {
                            HorizontallyPositionedViewContainer(centeredAt: geometry[anchor].x) {
                                Text(formatters.glucoseFormatter.string(from: selectedElement.quantity)!)
                                    .bold()
                            }
                        }
                    }
                }
            }
        }
    }

    private func getSelectedPoint(selectedElement: GlucoseEffect?, proxy: ChartProxy) -> CGPoint {
        if let selectedElement {
            let point = proxy.position(for: (
                x: selectedElement.startDate,
                y: selectedElement.quantity.doubleValue(for: formatters.glucoseUnit)
            ))
            return point ?? .zero
        } else {
            return .zero
        }
    }

    private func findElement(by date: Date?) -> GlucoseEffect? {
        guard let date else {
            return nil
        }

        // Find the closest date element.
        var minDistance: TimeInterval = .infinity
        var index: Int? = nil
        for dataIndex in glucoseEffect.indices {
            let nthDataDistance = glucoseEffect[dataIndex].startDate.distance(to: date)
            if abs(nthDataDistance) < minDistance {
                minDistance = abs(nthDataDistance)
                index = dataIndex
            }
        }
        if let index {
            return glucoseEffect[index]
        }
        return nil
    }}

struct GlucoseEffectChart_Previews: PreviewProvider {
    static var previews: some View {

        let end = Date()
        let start = end.addingTimeInterval(-18 * 3600)
        let effect = stride(from: start, through: end, by: TimeInterval(5 * 60)).map { date in
            let value = sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 5) / (3600*5) * Double.pi * 2) * 10
            let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value)
            return GlucoseEffect(startDate: date, quantity: quantity)
        }

        return GlucoseEffectChart(startTime: start, endTime:end, glucoseEffect: effect, upperRightLabel: "", chartUnitOffset: .constant(0), numSegments: 6)
            .opaqueHorizontalPadding()
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
