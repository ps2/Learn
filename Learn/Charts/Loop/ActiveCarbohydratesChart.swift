//
//  ActiveCarbohydratesChart.swift
//  Learn
//
//  Created by Pete Schwamb on 9/3/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import LoopKit
import HealthKit
import LoopAlgorithm

struct ActiveCarbohydratesChart: View {
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
    private var activeCarbs: [CarbValue]

    init(startTime: Date, endTime: Date, activeCarbs: [CarbValue], chartUnitOffset: Binding<Int>, numSegments: Int)  {
        self.startTime = startTime
        self.endTime = endTime
        self.activeCarbs = activeCarbs
        self._chartUnitOffset = chartUnitOffset
        self.numSegments = numSegments
        if activeCarbs.isEmpty {
            self.yScale = 0...10
        } else {
            let carbValues = activeCarbs.map { $0.value }
            let max = carbValues.max()!.roundedUp(toMultipleOf: 10)
            self.yScale = 0...max
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
        .chartXAxis(.hidden)
        .padding(.bottom, 18)
    }

    var body: some View {
        let inspectedElement = findElement(by: localInspectionDate ?? chartInspectionDate)
        VStack {
            HStack {
                Text("Active Carbohydrates").bold()
                Spacer()
            }
            .opacity(inspectedElement == nil ? 1 : 0)

            ScrollableChart(yAxis: yAxis, chartUnitOffset: $chartUnitOffset, height: 100, numSegments: numSegments) {
                Chart {
                    ForEach(activeCarbs, id: \.startDate) { carbValue in
                        AreaMark(
                            x: .value("Time", carbValue.startDate),
                            y: .value("Value", carbValue.value)
                        )
                        .foregroundStyle(Color.carbs.opacity(0.5))
                        LineMark(
                            x: .value("Time", carbValue.startDate),
                            y: .value("Value", carbValue.value)
                        )
                        .foregroundStyle(Color.carbs)

                    }
                    if let inspectedElement {
                        PointMark(
                            x: .value("Time", inspectedElement.startDate, unit: .second),
                            y: .value("Value", inspectedElement.value)
                        )
                        .foregroundStyle(Color.carbs.opacity(0.4))
                        .symbolSize(CGSize(width: 15, height: 15))
                    }

                }
                .chartYScale(domain: yScale)
                .chartXScale(domain: xScale)
                .chartInspection()
                .chartOverlay { proxy in
                    Color.clear.anchorPreference(key: ChartInspectionAnchorPreferenceKey.self, value: .point(getSelectedPoint(selectedElement: inspectedElement, proxy: proxy))) { $0 }
                }
                .dateTimeXAxis(values: .stride(by: .hour), labelOpacity: inspectedElement == nil ? 1 : 0)
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
                                Text(formatters.carbFormatter.string(
                                    from: HKQuantity(unit: .gram(), doubleValue: selectedElement.value))!)
                                    .bold()
                                    .foregroundStyle(Color.carbs)
                            }
                            .padding(.top, 5)
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

    private func getSelectedPoint(selectedElement: CarbValue?, proxy: ChartProxy) -> CGPoint {
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

    private func findElement(by date: Date?) -> CarbValue? {
        guard let date else {
            return nil
        }

        // Find the closest date element.
        var minDistance: TimeInterval = .infinity
        var index: Int? = nil
        for dataIndex in activeCarbs.indices {
            let nthDataDistance = activeCarbs[dataIndex].startDate.distance(to: date)
            if abs(nthDataDistance) < minDistance {
                minDistance = abs(nthDataDistance)
                index = dataIndex
            }
        }
        if let index {
            return activeCarbs[index]
        }
        return nil
    }
}

struct ActiveCarbohydratesChart_Previews: PreviewProvider {
    static var previews: some View {

        let end = Date()
        let start = end.addingTimeInterval(-18 * 3600)
        let delta = TimeInterval(minutes: 5)
        let carbValues = stride(from: start, through: end, by: delta).map { date in
            let value = sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 5) / (3600*5) * Double.pi * 2) * 10 + 10
            return CarbValue(startDate: date, value: value)
        }

        return ActiveCarbohydratesChart(startTime: start, endTime: end, activeCarbs: carbValues, chartUnitOffset: .constant(0), numSegments: 6)
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
            .dateTimeXAxis()
    }
}
