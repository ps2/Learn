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
import LoopKit

protocol DateSelectableValue {
    var dateForSelection: Date { get }
    var selectionValue: Double { get }
}

extension DoseEntry: Identifiable {
    public var id: String {
        return syncIdentifier ?? startDate.description
    }
}

extension DoseEntry: DateSelectableValue {
    var dateForSelection: Date {
        return startDate
    }

    var selectionValue: Double {
        switch type {
        case .bolus:
            return deliveredUnits ?? programmedUnits
        default:
            return unitsPerHour
        }
    }
}

struct InsulinDosesChart: View {
    @EnvironmentObject private var formatters: QuantityFormatters
    @Environment(\.chartInspectionDate) private var chartInspectionDate

    @State private var localInspectionDate: Date?

    private let desiredYAxisNumberOfMarks: Int = 4
    private let chartYDomain = 0...4

    private var xScale: ClosedRange<Date> { startTime...endTime }

    private var doses: [DoseEntry]
    private var basalHistory: [AbsoluteScheduleValue<Double>]

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
                return StrokeStyle(dash: [2,2])
            }
        }
    }

    struct BasalRatePoint: Hashable {
        let date: Date
        let rate: Double
        let type: BasalRatePointType
    }

    var basalPoints: [BasalRatePoint]
    var basalDoses: [DoseEntry]


    init(startTime: Date, endTime: Date, doses: [DoseEntry], basalHistory: [AbsoluteScheduleValue<Double>], chartUnitOffset: Binding<Int>, numSegments: Int) {
        self.startTime = startTime
        self.endTime = endTime
        self.doses = doses
        self.basalHistory = basalHistory
        self._chartUnitOffset = chartUnitOffset
        self.numSegments = numSegments

        // Fill in missing basal doses with basal history
        basalDoses = doses.infill(with: basalHistory, endDate: min(endTime, Date()), gapPatchInterval: .seconds(10))

        // Includes points for both scheduled (dotted) and dose (solid) lines.
        var basalLines = [BasalRatePoint]()

        for dose in basalDoses {
            switch dose.type {
            case .basal, .tempBasal, .suspend:
                basalLines.append(BasalRatePoint(date: dose.startDate, rate: dose.unitsPerHour, type: .dose))
                basalLines.append(BasalRatePoint(date: dose.endDate, rate: dose.unitsPerHour, type: .dose))
            default:
                break
            }
        }
        if var previousItem = basalHistory.first {
            for item in basalHistory {
                if item.startDate != previousItem.startDate {
                    basalLines.append(BasalRatePoint(date: item.startDate, rate: previousItem.value, type: .schedule))
                }
                basalLines.append(BasalRatePoint(date: item.startDate, rate: item.value, type: .schedule))
                previousItem = item
            }
            if previousItem.startDate < endTime {
                basalLines.append(BasalRatePoint(date: endTime, rate: previousItem.value, type: .schedule))
            }
        }
        basalPoints = basalLines
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
        .frame(width:30, alignment: .trailing)
    }

    var body: some View {
        let inspectedElement = findElement(by: localInspectionDate ?? chartInspectionDate)
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
                    ForEach(doses) { dose in
                        if dose.type == .bolus {
                            PointMark(
                                x: .value("Time", dose.startDate, unit: .second),
                                y: .value("Value", dose.deliveredUnits ?? dose.programmedUnits)
                            )
                            .symbol {
                                Image("bolus")
                                    .foregroundColor(.insulin)
                            }
                            .interpolationMethod(.cardinal)
                            .foregroundStyle(.orange.opacity(0.4))
                        }
                    }
                    // Basal Doses
                    ForEach(basalDoses) { dose in
                        RectangleMark(
                            xStart: .value("Start Time", dose.startDate),
                            xEnd: .value("End Time", dose.endDate),
                            yStart: .value("Base", 0),
                            yEnd: .value("Base", dose.unitsPerHour))
                        .foregroundStyle(Color.insulin.opacity(0.5))
                    }
                    // Basal Schedule
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
                .onPreferenceChange(ChartInspectionDatePreferenceKey.self) { date in
                    localInspectionDate = date
                }
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
                        if let inspectedElement {
                            HorizontallyPositionedViewContainer(centeredAt: geometry[anchor].x) {

                                if let dose = inspectedElement as? DoseEntry, dose.type == .bolus {
                                    Text(formatters.insulinFormatter.string(from: HKQuantity(unit: .internationalUnit(), doubleValue: dose.deliveredUnits ?? dose.programmedUnits))!)
                                        .bold()
                                        .foregroundStyle(Color.insulin)
                                } else {
                                    Text(formatters.insulinRateFormatter.string(from: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: inspectedElement.selectionValue))!)
                                        .bold()
                                        .foregroundStyle(Color.insulin)
                                }
                            }
                            Spacer()
                            // TODO: Add inspection date here
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

        for dose in doses + basalDoses {
            if dose.dateForSelection < date {
                let distance = abs(dose.dateForSelection.distance(to: date))
                if distance < minDistance {
                    minDistance = distance
                    selection = dose
                }
            }
        }

        var rate: Double? = nil

        for basal in basalHistory {
            if rate != basal.value && basal.startDate < date {
                let distance = abs(basal.startDate.distance(to: date))
                if distance < minDistance {
                    minDistance = distance
                    selection = basal
                }
            }
            rate = basal.value
        }

        return selection
    }
}

extension AbsoluteScheduleValue<Double>: DateSelectableValue {
    var dateForSelection: Date {
        return startDate
    }

    var selectionValue: Double {
        return value
    }
}


struct InsulinDosesChart_Previews: PreviewProvider {
    static var previews: some View {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-18 * 3600)

        let mockDataSource = MockDataSource()
        let interval = DateInterval(start: startDate, end: endDate)

        let doses = mockDataSource.getMockDoses(interval: interval)
        let basalHistory = mockDataSource.getMockBasalHistory(start: interval.start, end: interval.end)

        return InsulinDosesChart(startTime: startDate, endTime: endDate, doses: doses, basalHistory: basalHistory, chartUnitOffset: .constant(0), numSegments: 6)
            .opaqueHorizontalPadding()
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
