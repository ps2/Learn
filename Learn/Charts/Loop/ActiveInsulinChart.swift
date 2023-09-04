//
//  ActiveInsulinChart.swift
//  Learn
//
//  Created by Pete Schwamb on 9/3/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import LoopKit
import HealthKit

struct ActiveInsulinChart: View {
    @EnvironmentObject private var formatters: QuantityFormatters

    @Environment(\.chartInspectionDate) private var chartInspectionDate

    @State private var localInspectionDate: Date?

    @Binding var chartUnitOffset: Int
    private let numSegments: Int

    private var yScale: ClosedRange<Double>

    private let desiredYAxisNumberOfMarks: Int = 4
    private var xScale: ClosedRange<Date> { return startTime...endTime }

    private var startTime: Date
    private var endTime: Date
    private var activeInsulin: [InsulinValue]

    init(startTime: Date, endTime: Date, activeInsulin: [InsulinValue], chartUnitOffset: Binding<Int>, numSegments: Int)  {
        self.startTime = startTime
        self.endTime = endTime
        self.activeInsulin = activeInsulin
        self._chartUnitOffset = chartUnitOffset
        self.numSegments = numSegments
        if activeInsulin.isEmpty {
            self.yScale = -3...3
        } else {
            let insulinValues = activeInsulin.map { $0.value }
            let min = insulinValues.min()!.roundedDown(toMultipleOf: 2)
            let max = insulinValues.max()!.roundedUp(toMultipleOf: 2)
            self.yScale = min...max
        }
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
        let inspectedElement = findElement(by: localInspectionDate ?? chartInspectionDate)
        VStack {
            HStack {
                Text("Active Insulin").bold()
                Spacer()
                Text("U")
                    .bold()
                    .foregroundColor(.secondary)
            }
            .opacity(inspectedElement == nil ? 1 : 0)

            ScrollableChart(yAxis: yAxis, chartUnitOffset: $chartUnitOffset, height: 100, numSegments: numSegments) {
                Chart {
                    ForEach(activeInsulin, id: \.startDate) { insulinValue in
                        AreaMark(
                            x: .value("Time", insulinValue.startDate),
                            y: .value("Value", insulinValue.value)
                        )
                        .foregroundStyle(Color.insulin.opacity(0.5))
                        LineMark(
                            x: .value("Time", insulinValue.startDate),
                            y: .value("Value", insulinValue.value)
                        )
                        .foregroundStyle(Color.insulin.opacity(0.5))

                    }
                    if let inspectedElement {
                        PointMark(
                            x: .value("Time", inspectedElement.startDate, unit: .second),
                            y: .value("Value", inspectedElement.value)
                        )
                        .foregroundStyle(Color.insulin.opacity(0.4))
                        .symbolSize(CGSize(width: 15, height: 15))
                    }

                }
                .chartYScale(domain: yScale)
                .chartXScale(domain: xScale)
                .chartLongPressInspection()
                .chartOverlay { proxy in
                    Color.clear.anchorPreference(key: ChartInspectionAnchorPreferenceKey.self, value: .point(getSelectedPoint(selectedElement: inspectedElement, proxy: proxy))) { $0 }
                }
                .timeXAxis(values: .stride(by: .hour), labelOpacity: inspectedElement == nil ? 1 : 0)
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
                                Text(formatters.insulinFormatter.string(
                                    from: HKQuantity(unit: .internationalUnit(), doubleValue: selectedElement.value))!)
                                    .bold()
                                    .foregroundStyle(Color.insulin)
                            }
                            Spacer()
                            HorizontallyPositionedViewContainer(centeredAt: geometry[anchor].x) {
                                Text(selectedElement.startDate.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }

    private func getSelectedPoint(selectedElement: InsulinValue?, proxy: ChartProxy) -> CGPoint {
        if let selectedElement {
            let point = proxy.position(for: (
                x: selectedElement.startDate,
                y: selectedElement.value
            ))
            return point ?? .zero
        } else {
            return .zero
        }
    }

    private func findElement(by date: Date?) -> InsulinValue? {
        guard let date else {
            return nil
        }

        // Find the closest date element.
        var minDistance: TimeInterval = .infinity
        var index: Int? = nil
        for dataIndex in activeInsulin.indices {
            let nthDataDistance = activeInsulin[dataIndex].startDate.distance(to: date)
            if abs(nthDataDistance) < minDistance {
                minDistance = abs(nthDataDistance)
                index = dataIndex
            }
        }
        if let index {
            return activeInsulin[index]
        }
        return nil
    }
}

struct IOBChart_Previews: PreviewProvider {
    static var previews: some View {

        let end = Date()
        let start = end.addingTimeInterval(-18 * 3600)
        let delta = TimeInterval(minutes: 5)
        let insulinValues = stride(from: start, through: end, by: delta).map { date in
            let value = sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 5) / (3600*5) * Double.pi * 2) * 10
            return InsulinValue(startDate: date, value: value)
        }

        return ActiveInsulinChart(startTime: start, endTime: end, activeInsulin: insulinValues, chartUnitOffset: .constant(0), numSegments: 6)
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
            .timeXAxis()
    }
}


