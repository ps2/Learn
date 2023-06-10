//
//  InsulinChart.swift
//  Learn
//
//  Created by Pete Schwamb on 1/15/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import HealthKit

protocol DateSelectableValue {
    var dateForSelection: Date { get }
    var selectionValue: Double { get }
}

struct Bolus: Identifiable, DateSelectableValue {
    var date: Date
    var amount: Double // Units
    var programmedAmount: Double? // Units
    var automatic: Bool
    var id: String

    var dateForSelection: Date { return date }
    var selectionValue: Double { return amount }
}

struct Basal: Identifiable, DateSelectableValue {
    var start: Date
    var end: Date
    var rate: Double // Units/hr
    var temporary: Bool
    var automatic: Bool
    var id: String
    var dateForSelection: Date

    var selectionValue: Double { return rate }

    init(start: Date, end: Date, rate: Double, temporary: Bool, automatic: Bool, id: String) {
        self.start = start
        self.end = end
        self.rate = rate
        self.temporary = temporary
        self.automatic = automatic
        self.id = id
        let duration = end.timeIntervalSince(start)
        self.dateForSelection = start.addingTimeInterval(duration / 2.0)
    }
}

struct ScheduledBasal: Identifiable, DateSelectableValue {
    var id: Date { return start }
    var start: Date
    var end: Date
    var rate: Double // Units/hr
    var automatic: Bool
    var dateForSelection: Date

    var selectionValue: Double { return rate }

    init(start: Date, end: Date, rate: Double, automatic: Bool) {
        self.start = start
        self.end = end
        self.rate = rate
        self.automatic = automatic

        let duration = end.timeIntervalSince(start)
        self.dateForSelection = start.addingTimeInterval(duration / 2.0)
    }
}

struct InsulinDeliveryChart: View {
    @EnvironmentObject private var formatters: QuantityFormatters
    @Environment(\.chartInspectionDate) private var chartInspectionDate

    private let desiredYAxisNumberOfMarks: Int = 4
    private let chartYDomain = 0...4

    private var xScale: ClosedRange<Date> { startTime...endTime }

    private var bolusDoses: [Bolus]
    private var basalDoses: [Basal]
    private var basalSchedule: [ScheduledBasal]

    private var startTime: Date
    private var endTime: Date
    private var numSegments: Int
    @Binding var chartUnitOffset: Int

    enum BasalRatePointType: Int {
        case dose
        case schedule

        var strokeStyle: StrokeStyle {
            switch self {
            case .dose:
                return StrokeStyle()
            case .schedule:
                return StrokeStyle(dash: [3,3])
            }
        }
    }

    struct BasalRatePoint: Hashable {
        let date: Date
        let rate: Double
        let type: BasalRatePointType
    }

    var basalPoints: [BasalRatePoint] {
        var points = [BasalRatePoint]()

        for dose in basalDoses {
            points.append(BasalRatePoint(date: dose.start, rate: dose.rate, type: .dose))
            points.append(BasalRatePoint(date: dose.end, rate: dose.rate, type: .dose))
        }
        for item in basalSchedule {
            points.append(BasalRatePoint(date: item.start, rate: item.rate, type: .schedule))
            points.append(BasalRatePoint(date: item.end, rate: item.rate, type: .schedule))
        }
        return points
    }


    init(bolusDoses: [Bolus], basalDoses: [Basal], basalSchedule: [ScheduledBasal], startTime: Date, endTime: Date, chartUnitOffset: Binding<Int>, numSegments: Int) {
        self.bolusDoses = bolusDoses
        self.basalDoses = basalDoses
        self.basalSchedule = basalSchedule
        self.startTime = startTime
        self.endTime = endTime
        self._chartUnitOffset = chartUnitOffset
        self.numSegments = numSegments
    }

    var yAxis: some View {
        Chart {
            PointMark(x: .value("Day", startTime, unit: .second), y: .value("Value", 0))
        }
        .chartYScale(domain: chartYDomain)
        .foregroundStyle(.clear)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: desiredYAxisNumberOfMarks))
        }
    }

    var body: some View {
        let inspectedElement = findElement(by: chartInspectionDate)
        VStack {
            HStack {
                Text("Insulin Delivery").bold()
                Spacer()
                Text("15 U")
                    .bold()
                    .foregroundColor(.secondary)
            }
            .opacity(inspectedElement == nil ? 1 : 0)

            ScrollableChart(yAxis: yAxis, chartUnitOffset: $chartUnitOffset, height: 250, numSegments: numSegments) {
                Chart {
                    // Boluses
                    ForEach(bolusDoses) { bolus in
                        PointMark(
                            x: .value("Time", bolus.date, unit: .second),
                            y: .value("Value", bolus.amount)
                        )
                        .symbol {
                            Image("bolus")
                                .foregroundColor(.insulin)
                        }
                        .interpolationMethod(.cardinal)
                        .foregroundStyle(.orange.opacity(0.4))
                    }
                    // Basal Schedule
                    // Basal Doses
                    ForEach(basalDoses) { dose in
                        RectangleMark(
                            xStart: .value("Start Time", dose.start),
                            xEnd: .value("End Time", dose.end),
                            yStart: .value("Base", 0),
                            yEnd: .value("Base", dose.rate))
                        .foregroundStyle(Color.insulin.opacity(0.5))
                    }
                    ForEach(basalPoints, id: \.self) { point in
                        LineMark(
                            x: .value("Time", point.date, unit: .second),
                            y: .value("Scheduled Rate", point.rate),
                            series: .value("Type", point.type.rawValue)
                        )
                        .lineStyle(point.type.strokeStyle)
                        .foregroundStyle(Color.insulin)
                    }

                    // Inspected element
                    if let inspectedElement {
                        PointMark(
                            x: .value("Time", inspectedElement.dateForSelection, unit: .second),
                            y: .value("Value", inspectedElement.selectionValue)
                        )
                        .foregroundStyle(.orange.opacity(0.4))
                        .symbolSize(CGSize(width: 15, height: 15))
                    }
                }
                .chartYScale(domain: chartYDomain)
                .chartXScale(domain: startTime...endTime)
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
                        if let bolus = inspectedElement as? Bolus {
                            HorizontallyPositionedViewContainer(centeredAt: geometry[anchor].x) {

                                Text(formatters.insulinFormatter.string(from: HKQuantity(unit: .internationalUnit(), doubleValue: bolus.amount))!)
                                    .bold()
                            }
                        } else if let inspectedElement {
                            HorizontallyPositionedViewContainer(centeredAt: geometry[anchor].x) {

                                Text(formatters.insulinRateFormatter.string(from: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: inspectedElement.selectionValue))!)
                                    .bold()
                            }
                        }
                    }
                }
            }
        }
    }

    private func getSelectedPoint(selectedElement: DateSelectableValue?, proxy: ChartProxy) -> CGPoint {
        if let selectedElement {
            let point = proxy.position(for: (
                x: selectedElement.dateForSelection,
                y: selectedElement.selectionValue
            ))
            return point ?? .zero
        } else {
            return .zero
        }
    }

    private func findElement(by date: Date?) -> DateSelectableValue? {
        guard let date else {
            return nil
        }

        // Find the closest date element.
        var minDistance: TimeInterval = .infinity
        var selection: DateSelectableValue?

        for bolus in bolusDoses {
            let distance = abs(bolus.dateForSelection.distance(to: date))
            if distance < minDistance {
                minDistance = distance
                selection = bolus
            }
        }

        for basal in basalDoses {
            let distance = abs(basal.dateForSelection.distance(to: date))
            if distance < minDistance {
                minDistance = distance
                selection = basal
            }
        }

        for scheduledBasal in basalSchedule {
            let distance = abs(scheduledBasal.dateForSelection.distance(to: date))
            if distance < minDistance {
                minDistance = distance
                selection = scheduledBasal
            }
        }

        return selection
    }
}


struct InsulinDeliveryChart_Previews: PreviewProvider {
    static var previews: some View {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-18 * 3600)

        let mockDataSource = MockDataSource()

        let boluses = mockDataSource.getMockBoluses(start: startDate, end: endDate)
        let basalSchedule = mockDataSource.getMockBasalSchedule(start: startDate, end: endDate)
        let basalDoses = mockDataSource.getMockBasalDoses(start: startDate, end: endDate)

        return InsulinDeliveryChart(bolusDoses: boluses, basalDoses: basalDoses, basalSchedule: basalSchedule, startTime: startDate, endTime: endDate, chartUnitOffset: .constant(0), numSegments: 6)
            .opaqueHorizontalPadding()
    }
}
