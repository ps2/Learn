//
//  GlucoseChart.swift
//  Learn
//
//  Created by Pete Schwamb on 1/10/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import HealthKit

struct GlucoseValue: Equatable {
    let quantity: HKQuantity
    let date: Date
}

struct TargetRange: Equatable {
    let min: HKQuantity
    let max: HKQuantity
    let startTime: Date
    let endTime: Date
}

struct GlucoseChart: View {

    @EnvironmentObject private var formatters: QuantityFormatters
    @Environment(\.chartInspectionDate) private var chartInspectionDate

    @Binding var chartUnitOffset: Int
    private let numSegments: Int

    private let desiredYAxisNumberOfMarks: Int = 4

    private var yScale: ClosedRange<Double> {
        if formatters.glucoseUnit == .milligramsPerDeciliter {
            return 0...400
        } else {
            return 0...22
        }
    }
    private var xScale: ClosedRange<Date> { return startTime...endTime }

    private var startTime: Date
    private var endTime: Date
    private var upperRightLabel: String

    private var historicalGlucose: [GlucoseValue]
    private var targetRanges: [TargetRange]

    init(startTime: Date, endTime: Date, upperRightLabel: String, chartUnitOffset: Binding<Int>, numSegments: Int, historicalGlucose: [GlucoseValue], targetRanges: [TargetRange])  {

        self.startTime = startTime
        self.endTime = endTime
        self.upperRightLabel = upperRightLabel
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
                Text(upperRightLabel)
                    .foregroundColor(.secondary)
            }
            .opacity(inspectedElement == nil ? 1 : 0)

            ScrollableChart(yAxis: yAxis, chartUnitOffset: $chartUnitOffset, height: 250, numSegments: numSegments) {
                Chart {
                    ForEach(historicalGlucose, id: \.date) { reading in
                        PointMark(
                            x: .value("Time", reading.date, unit: .second),
                            y: .value("Historical Glucose", reading.quantity.doubleValue(for: formatters.glucoseUnit))
                        )
                        .foregroundStyle(Color.glucose)
                        .symbolSize(CGSize(width: 5, height: 5))
                    }
                    if let inspectedElement {
                        PointMark(
                            x: .value("Time", inspectedElement.date, unit: .second),
                            y: .value("Historical Glucose", inspectedElement.quantity.doubleValue(for: formatters.glucoseUnit))
                        )
                        .foregroundStyle(.secondary)
                        .symbolSize(CGSize(width: 15, height: 15))
                    }

                    ForEach(targetRanges, id: \.startTime) { target in
                        RectangleMark(
                            xStart: .value("Segment Start", target.startTime, unit: .second),
                            xEnd: .value("Segment End", target.endTime, unit: .second),
                            yStart: .value("TargetBottom", target.min.doubleValue(for: formatters.glucoseUnit)),
                            yEnd: .value("TargetTop", target.max.doubleValue(for: formatters.glucoseUnit))
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
                    AxisMarks(values: .stride(by: .hour)) { value in
                            if let date = value.as(Date.self) {
                                let hour = Calendar.current.component(.hour, from: date)
                                AxisValueLabel {
                                    VStack(alignment: .leading) {
                                        switch hour {
                                        case 0, 12:
                                            Text(date, format: .dateTime.hour())
                                        default:
                                            Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                                        }
                                        if value.index == 0 || hour == 0 {
                                            Text(date, format: .dateTime.month().day())
                                        }
                                    }
                                }

                                if hour == 0 {
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                                } else {
                                    AxisGridLine()
                                    AxisTick()
                                }
                            }
                        }
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
                                Text(formatters.glucoseFormatter.string(from: selectedElement.quantity)!)
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
                y: selectedElement.quantity.doubleValue(for: formatters.glucoseUnit)
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

        let mockDataSource = MockDataSource()
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-18 * 3600)
        let glucose = mockDataSource.getMockGlucoseValues(start: startDate, end: endDate)
        let targets = mockDataSource.getMockTargetRanges(start: startDate, end: endDate)

        return GlucoseChart(startTime: startDate, endTime:endDate, upperRightLabel: "", chartUnitOffset: .constant(0), numSegments: 6, historicalGlucose: glucose, targetRanges: targets)
            .opaqueHorizontalPadding()
            .environmentObject(QuantityFormatters(glucoseUnit: .millimolesPerLiter))
    }
}
