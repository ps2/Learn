//
//  GlucoseChart.swift
//  Learn
//
//  Created by Pete Schwamb on 1/10/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import LoopKit

struct GlucoseValue: Equatable {
    let value: Double
    let date: Date
}

struct TargetRange: Equatable {
    let range: DoubleRange
    let startTime: Date
    let endTime: Date
}

struct GlucoseChart: View {

    @Environment(\.chartInspectionDate) private var chartInspectionDate
    @Binding var chartUnitOffset: Int
    private let numSegments: Int

    private let desiredYAxisNumberOfMarks: Int = 4

    private let yScale = 0...400

    private var xScale: ClosedRange<Date> { return startTime...endTime }

    private var startTime: Date
    private var endTime: Date

    private var historicalGlucose: [GlucoseValue]
    private var targetRanges: [TargetRange]

    init(startTime: Date, endTime: Date, chartUnitOffset: Binding<Int>, numSegments: Int, historicalGlucose: [GlucoseValue], targetRanges: [TargetRange])  {
        self.startTime = startTime
        self.endTime = endTime
        self._chartUnitOffset = chartUnitOffset
        self.numSegments = numSegments
        self.historicalGlucose = historicalGlucose
        self.targetRanges = targetRanges
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
    }

    var body: some View {
        let inspectedElement = findElement(by: chartInspectionDate)
        VStack {
            HStack {
                Text("Glucose").bold()
                Spacer()
                Text("Eventually 112 mg/dL")
                    .bold()
                    .foregroundColor(.secondary)
            }
            .opacity(inspectedElement == nil ? 1 : 0)

            ScrollableChart(yAxis: yAxis, chartUnitOffset: $chartUnitOffset, height: 250, numSegments: numSegments) {
                Chart {
                    ForEach(historicalGlucose, id: \.date) { reading in
                        PointMark(
                            x: .value("Time", reading.date, unit: .second),
                            y: .value("Historical Glucose", reading.value)
                        )
                        .symbolSize(CGSize(width: 5, height: 5))
                    }
                    if let inspectedElement {
                        PointMark(
                            x: .value("Time", inspectedElement.date, unit: .second),
                            y: .value("Historical Glucose", inspectedElement.value)
                        )
                        .foregroundStyle(.tertiary)
                        .symbolSize(CGSize(width: 15, height: 15))
                    }

                    ForEach(targetRanges, id: \.startTime) { target in
                        RectangleMark(
                            xStart: .value("Segment Start", target.startTime, unit: .second),
                            xEnd: .value("Segment End", target.endTime, unit: .second),
                            yStart: .value("TargetBottom", target.range.minValue),
                            yEnd: .value("TargetTop", target.range.maxValue)
                        )
                        .foregroundStyle(.tertiary)
                    }
                }
                .chartYScale(domain: yScale)
                .chartXScale(domain: xScale)
                .chartLongPressInspection()
                .chartOverlay { proxy in
                    Color.clear.anchorPreference(key: ChartInspectionAnchorPreferenceKey.self, value: .point(getSelectedPoint(selectedElement: inspectedElement, proxy: proxy))) { $0 }
                }
                .chartXAxis {
                    AxisMarks(
                        format: .dateTime.hour(),
                        preset: .extended,
                        values: .stride(by: .hour)
                    )
                }
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
                                Text("\(selectedElement.value, format: .number) mg/dL")
                                    .bold()
                            }
                        }
                    }
                }
            }
        }
    }

    private func getSelectedPoint(selectedElement: GlucoseValue?, proxy: ChartProxy) -> CGPoint {
        if let selectedElement {
            let point = proxy.position(for: (
                x: selectedElement.date,
                y: selectedElement.value
            ))
            return point ?? .zero
        } else {
            return .zero
        }
    }

    private func findElement(by date: Date?) -> GlucoseValue? {
        guard let date else {
            return nil
        }

        // Find the closest date element.
        var minDistance: TimeInterval = .infinity
        var index: Int? = nil
        for dataIndex in historicalGlucose.indices {
            let nthDataDistance = historicalGlucose[dataIndex].date.distance(to: date)
            if abs(nthDataDistance) < minDistance {
                minDistance = abs(nthDataDistance)
                index = dataIndex
            }
        }
        if let index {
            return historicalGlucose[index]
        }
        return nil
    }
}


struct GlucoseChart_Previews: PreviewProvider {
    static var previews: some View {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-18 * 3600)


        let glucose = stride(from: startDate, through: endDate, by: TimeInterval(5 * 60)).map { date in
            let value = 110.0 + sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 5) / (3600*5) * Double.pi * 2) * 60
            return GlucoseValue(value: value, date: date)
        }

        let targetTimeInterval = TimeInterval(90 * 60)

        let targets = stride(from: startDate, through: endDate, by: targetTimeInterval).map { date in
            let value = 110.0 + sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 2) / (3600*3) * Double.pi * 2) * 10
            return TargetRange(range: DoubleRange(minValue: value-5, maxValue: value+5), startTime: date, endTime: date.addingTimeInterval(targetTimeInterval))
        }
        return GlucoseChart(startTime: startDate, endTime:endDate, chartUnitOffset: .constant(0), numSegments: 6, historicalGlucose: glucose, targetRanges: targets)
            .padding()
    }
}
