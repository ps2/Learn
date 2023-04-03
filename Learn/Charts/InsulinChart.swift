//
//  InsulinChart. ift
//  Learn
//
//  Created by Pete Schwamb on 1/15/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts

struct InsulinValue: Equatable {
    let value: Double
    let date: Date
}

struct InsulinChart: View {

    @Environment(\.chartInspectionDate) private var chartInspectionDate

    private let desiredYAxisNumberOfMarks: Int = 4
    private let chartYDomain = 0...400

    private var xScale: ClosedRange<Date> { startTime...endTime }

    private var data: [InsulinValue]
    private var startTime: Date
    private var endTime: Date
    private var numSegments: Int
    @Binding var chartUnitOffset: Int


    init(data: [InsulinValue], startTime: Date, endTime: Date, chartUnitOffset: Binding<Int>, numSegments: Int) {
        self.data = data
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
                Text("Insulin").bold()
                Spacer()
                Text("15 U")
                    .bold()
                    .foregroundColor(.secondary)
            }
            .opacity(inspectedElement == nil ? 1 : 0)

            ScrollableChart(yAxis: yAxis, chartUnitOffset: $chartUnitOffset, height: 250, numSegments: numSegments) {
                Chart {
                    ForEach(data, id: \.date) { reading in
                        AreaMark(
                            x: .value("Time", reading.date, unit: .second),
                            y: .value("Value", reading.value)
                        )
                        .interpolationMethod(.cardinal)
                        .foregroundStyle(.orange.opacity(0.4))

                        LineMark(
                            x: .value("Time", reading.date, unit: .second),
                            y: .value("Value", reading.value)
                        )
                        .interpolationMethod(.cardinal)
                        .lineStyle(StrokeStyle(lineWidth: 4))
                        .foregroundStyle(.orange)
                    }
                    if let inspectedElement {
                        PointMark(
                            x: .value("Time", inspectedElement.date, unit: .second),
                            y: .value("Value", inspectedElement.value)
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

    private func getSelectedPoint(selectedElement: InsulinValue?, proxy: ChartProxy) -> CGPoint {
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

    private func findElement(by date: Date?) -> InsulinValue? {
        guard let date else {
            return nil
        }

        // Find the closest date element.
        // Find the closest date element.
        var minDistance: TimeInterval = .infinity
        var index: Int? = nil
        for dataIndex in data.indices {
            let nthDataDistance = data[dataIndex].date.distance(to: date)
            if abs(nthDataDistance) < minDistance {
                minDistance = abs(nthDataDistance)
                index = dataIndex
            }
        }
        if let index {
            return data[index]
        }
        return nil
    }
}


struct InsulinChart_Previews: PreviewProvider {
    static var previews: some View {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-18 * 3600)

        let data = stride(from: startDate, through: endDate, by: TimeInterval(5 * 60)).map { date in
            let value = 110.0 + sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 2) / (3600*2) * Double.pi * 2) * 30
            return InsulinValue(value: value, date: date)
        }
        return InsulinChart(data: data, startTime: startDate, endTime:endDate, chartUnitOffset: .constant(0), numSegments: 6)
            .padding()
    }
}
