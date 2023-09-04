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
import LoopKit

struct TargetRange: Equatable {
    let min: HKQuantity
    let max: HKQuantity
    let startTime: Date
    let endTime: Date
}

struct LoopGlucoseChart: View {

    @EnvironmentObject private var formatters: QuantityFormatters
    @Environment(\.chartInspectionDate) private var chartInspectionDate

    @State private var localInspectionDate: Date?

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

    private var historicalGlucose: [GlucoseSampleValue]
    private var targetRanges: [AbsoluteScheduleValue<ClosedRange<HKQuantity>>]
    private var carbEntries: [CarbEntry]

    init(startTime: Date, endTime: Date, historicalGlucose: [GlucoseSampleValue], targetRanges: [AbsoluteScheduleValue<ClosedRange<HKQuantity>>], carbEntries: [CarbEntry], upperRightLabel: String, chartUnitOffset: Binding<Int>, numSegments: Int)  {

        self.startTime = startTime
        self.endTime = endTime
        self.historicalGlucose = historicalGlucose
        self.targetRanges = targetRanges
        self.carbEntries = carbEntries
        self.upperRightLabel = upperRightLabel
        self._chartUnitOffset = chartUnitOffset
        self.numSegments = numSegments
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
                Text("Glucose").bold()
                Spacer()
                Text(upperRightLabel)
                    .foregroundColor(.secondary)
            }
            .opacity(inspectedElement == nil ? 1 : 0)

            ScrollableChart(yAxis: yAxis, chartUnitOffset: $chartUnitOffset, height: 250, numSegments: numSegments) {
                Chart {
                    ForEach(historicalGlucose, id: \.startDate) { reading in
                        PointMark(
                            x: .value("Time", reading.startDate, unit: .second),
                            y: .value("Historical Glucose", reading.quantity.doubleValue(for: formatters.glucoseUnit))
                        )
                        .foregroundStyle(Color.glucose)
                        .symbolSize(CGSize(width: 5, height: 5))
                    }
                    ForEach(carbEntries, id: \.startDate) { entry in
                        PointMark(
                            x: .value("Time", entry.startDate, unit: .second),
                            y: 12
                        )
                        .symbol {
                            Image(systemName: "fork.knife.circle")
                                .foregroundColor(.carbs)
                        }
                        .annotation(position: .bottom, spacing: 0) {
                            Text(formatters.carbFormatter.string(from: entry.quantity)!)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let inspectedElement {
                        PointMark(
                            x: .value("Time", inspectedElement.startDate, unit: .second),
                            y: .value("Historical Glucose", inspectedElement.quantity.doubleValue(for: formatters.glucoseUnit))
                        )
                        .foregroundStyle(.secondary)
                        .symbolSize(CGSize(width: 15, height: 15))
                    }

                    ForEach(targetRanges, id: \.startDate) { target in
                        RectangleMark(
                            xStart: .value("Segment Start", target.startDate, unit: .second),
                            xEnd: .value("Segment End", target.endDate, unit: .second),
                            yStart: .value("TargetBottom", target.value.lowerBound.doubleValue(for: formatters.glucoseUnit)),
                            yEnd: .value("TargetTop", target.value.upperBound.doubleValue(for: formatters.glucoseUnit))
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
                                Text(formatters.glucoseFormatter.string(from: selectedElement.quantity)!)
                                    .bold()
                                    .foregroundStyle(Color.glucose)
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
        .onPreferenceChange(ChartInspectionDatePreferenceKey.self) { date in
            localInspectionDate = date
        }
    }

    private func getSelectedPoint(selectedElement: GlucoseSampleValue?, proxy: ChartProxy) -> CGPoint {
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

    private func findElement(by date: Date?) -> GlucoseSampleValue? {
        guard let date else {
            return nil
        }

        // Find the closest date element.
        var minDistance: TimeInterval = .infinity
        var index: Int? = nil
        for dataIndex in historicalGlucose.indices {
            let nthDataDistance = historicalGlucose[dataIndex].startDate.distance(to: date)
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
        let carbEntries = mockDataSource.getMockCarbEntries(start: startDate, end: endDate)

        return LoopGlucoseChart(startTime: startDate, endTime:endDate, historicalGlucose: glucose, targetRanges: targets, carbEntries: carbEntries, upperRightLabel: "", chartUnitOffset: .constant(0), numSegments: 6)
            .opaqueHorizontalPadding()
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
