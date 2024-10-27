//
//  InsulinDeliverChart.swift
//  Learn
//
//  Created by Pete Schwamb on 1/15/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import HealthKit
import LoopKit
import LoopAlgorithm

struct DeliverySegment {
    var startTime: Date
    var endTime: Date
    var rate: Double
}

extension Sequence where Element == DoseEntry {

}

extension DoseEntry {
    func splitIntoSimulationTimelineDeliverySegments(using interval: TimeInterval = .minutes(5)) -> [DeliverySegment] {
        var out: [DeliverySegment] = []
        var date = startDate
        let intervalHourRate = TimeInterval(hours: 1) / interval
        while date < endDate {
            let segmentEnd = min(endDate, date.addingTimeInterval(interval).dateFlooredToTimeInterval(interval))
            let portion = segmentEnd.timeIntervalSince(date) / duration
            let segmentVolume = (deliveredUnits ?? programmedUnits) * portion
            out.append(DeliverySegment(startTime: date, endTime: segmentEnd, rate: segmentVolume * intervalHourRate))
            date = segmentEnd
        }
        return out
    }
}

struct AutomatedDeliveryChart: View {
    @EnvironmentObject private var formatters: QuantityFormatters
    @Environment(\.chartInspectionDate) private var chartInspectionDate

    @State private var localInspectionDate: Date?

    private let desiredYAxisNumberOfMarks: Int = 4
    private let chartYDomain: ClosedRange<Double> = 0...10

    private var maxDoseValue: Double {
        return chartYDomain.upperBound - 0.2
    }

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
                return StrokeStyle(lineWidth: 2)
            case .schedule:
                return StrokeStyle(dash: [2,2])
            }
        }
    }

    struct BasalRatePoint: Hashable {
        let date: Date
        let rate: Double
    }

    var deliveryPoints: [BasalRatePoint]
    var basalDoses: [DoseEntry]
    var deliverySegments: [DeliverySegment]


    init(startTime: Date, endTime: Date, doses: [DoseEntry], basalHistory: [AbsoluteScheduleValue<Double>], chartUnitOffset: Binding<Int>, numSegments: Int, basalEndTime: Date? = nil) {
        self.startTime = startTime
        self.endTime = endTime
        self.doses = doses
        self.basalHistory = basalHistory
        self._chartUnitOffset = chartUnitOffset
        self.numSegments = numSegments

        // Fill in missing basal doses with basal history
        let end = basalEndTime ?? Date()
        basalDoses = doses.overlayBasal(basalHistory, endDate: end, lastPumpEventsReconciliation: end, gapPatchInterval: .seconds(10))

        let boluses = doses.filter { $0.type == .bolus }

        let allDoses = basalDoses + boluses
        let allSegments = allDoses.flatMap { $0.splitIntoSimulationTimelineDeliverySegments() }

        let simulationTimelineStart = startTime.dateFlooredToTimeInterval(GlucoseMath.defaultDelta)
        let simulationTimelineEnd = endTime.dateCeiledToTimeInterval(GlucoseMath.defaultDelta)
        var segmentStart = simulationTimelineStart
        deliverySegments = []
        while segmentStart < simulationTimelineEnd {
            deliverySegments.append(DeliverySegment(startTime: segmentStart, endTime: segmentStart.addingTimeInterval(GlucoseMath.defaultDelta), rate: 0))
            segmentStart += GlucoseMath.defaultDelta
        }

        for delivery in allSegments {
            let idx = Int(delivery.startTime.timeIntervalSince(simulationTimelineStart) / GlucoseMath.defaultDelta)
            if idx > 0 && idx < deliverySegments.count {
                deliverySegments[idx].rate += delivery.rate
            }
        }


        var deliveryLines = [BasalRatePoint]()

        for segment in deliverySegments {
            deliveryLines.append(BasalRatePoint(date: segment.endTime, rate: segment.rate))
        }
        deliveryPoints = deliveryLines
    }

    var yAxis: some View {
        Chart {
            PointMark(x: .value("Day", startTime, unit: .second), y: .value("Value", 0))
        }
        .chartYScale(domain: chartYDomain)
        .foregroundStyle(.clear)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: desiredYAxisNumberOfMarks)) { value in
                AxisValueLabel()
                    .font(.system(size: 14))
            }
        }
        .frame(width:30, alignment: .trailing)
        .chartXAxis(.hidden)
        .padding(.bottom, 18)
    }

    func clippedBolusValue(units: Double) -> Double {
        return min(maxDoseValue, units)
    }

    var body: some View {
        let inspectedElement = findElement(by: localInspectionDate ?? chartInspectionDate)
        VStack {
            HStack {
                Text("Automated Delivery").bold()
                Spacer()
            }
            .opacity(inspectedElement == nil ? 1 : 0)

            ScrollableChart(yAxis: yAxis, chartUnitOffset: $chartUnitOffset, height: 100, numSegments: numSegments) {
                Chart {
                    // Automated Delivery
                    ForEach(deliveryPoints, id: \.self) { point in
                        LineMark(
                            x: .value("Time", point.date, unit: .second),
                            y: .value("Scheduled Rate", point.rate)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(Color.insulin)
                        .interpolationMethod(.cardinal)
                    }

                    // Inspected element
                    if let inspectedElement {
                        if let dose = inspectedElement as? DoseEntry, dose.type == .bolus, dose.automatic == true {
                            PointMark(
                                x: .value("Time", dose.startDate, unit: .second),
                                y: .value("Value", clippedBolusValue(units: inspectedElement.selectionValue))
                            )
                            .symbol {
                                dose.selectedSymbol
                            }
                        } else {
                            PointMark(
                                x: .value("Time", inspectedElement.dateForSelection, unit: .second),
                                y: .value("Value", clippedBolusValue(units: inspectedElement.selectionValue))
                            )

                            .foregroundStyle(Color.insulin.opacity(0.4))
                            .symbolSize(CGSize(width: 15, height: 15))
                        }
                    }
                }
                .chartYScale(domain: chartYDomain)
                .chartXScale(domain: startTime...endTime)
                .chartInspection()
                .onPreferenceChange(ChartInspectionDatePreferenceKey.self) { date in
                    localInspectionDate = date
                }
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
                        if let inspectedElement, let dose = inspectedElement as? DoseEntry {
                            HorizontallyPositionedViewContainer(centeredAt: geometry[anchor].x) {
                                if dose.type == .bolus {
                                    Text(formatters.insulinFormatter.string(from: HKQuantity(unit: .internationalUnit(), doubleValue: dose.deliveredUnits ?? dose.programmedUnits))!)
                                        .bold()
                                        .foregroundStyle(Color.insulin)
                                } else {
                                    Text(formatters.insulinRateFormatter.string(from: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: inspectedElement.selectionValue))!)
                                        .bold()
                                        .foregroundStyle(Color.insulin)
                                }
                            }
                            .padding(.top, 5)
                            Spacer()
                            HorizontallyPositionedViewContainer(centeredAt: geometry[anchor].x) {
                                Text(dose.startDate.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(.secondary)
                                .font(.caption)
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


struct AutomatedDeliveryChart_Previews: PreviewProvider {
    static var previews: some View {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-18 * 3600)

        let mockDataSource = MockDataSource()
        let interval = DateInterval(start: startDate, end: endDate)

        let doses = mockDataSource.getMockDoses(interval: interval)
        let basalHistory = mockDataSource.getMockBasalHistory(start: interval.start, end: interval.end)

        return AutomatedDeliveryChart(startTime: startDate, endTime: endDate, doses: doses, basalHistory: basalHistory, chartUnitOffset: .constant(0), numSegments: 6)
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
            .opaqueHorizontalPadding()
    }
}
