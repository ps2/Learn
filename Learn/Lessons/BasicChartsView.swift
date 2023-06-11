//
//  BasicChartsView.swift
//  Learn
//
//  Created by Pete Schwamb on 2/22/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct BasicChartsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ObservedObject private var scrollCoordinator = ChartScrollCoordinator()

    @State private var glucoseDataValues: [GlucoseValue] = []
    @State private var targetRanges: [TargetRange] = []
    @State private var boluses: [Bolus] = []
    @State private var basalSchedule: [ScheduledBasal] = []
    @State private var basalDoses: [Basal] = []

    // When in inspection mode, the date being inspected
    @State var inspectionDate: Date?

    private var dataSource: any DataSource
    private let baseTime: Date

    init(dataSource: any DataSource) {
        self.dataSource = dataSource
        print("DataSource.endOfData = \(String(describing: dataSource.endOfData))")
        baseTime = (dataSource.endOfData ?? Date()).roundDownToHour()!
    }

    var displayedTimeInterval: TimeInterval {
        if horizontalSizeClass == .compact {
            return TimeInterval(hours: 6)
        } else {
            return TimeInterval(hours: 12)
        }
    }

    var start: Date {
        return scrolledToTime.addingTimeInterval(-(displayedTimeInterval * 1.5))
    }

    var end: Date {
        return scrolledToTime.addingTimeInterval(displayedTimeInterval * 1.5)
    }

    var scrolledToTime: Date {
        return baseTime.addingTimeInterval(segmentSize * Double(scrollCoordinator.chartUnitOffset))
    }

    var segmentSize = TimeInterval(hours: 1) // Panning "snaps" to these segments

    var numSegments: Int {
        return Int((displayedTimeInterval / segmentSize).rounded())
    }

    private var dateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var dateStr: String {
        return dateIntervalFormatter.string(
            from: scrolledToTime.addingTimeInterval(-(displayedTimeInterval * 0.5)),
            to: scrolledToTime.addingTimeInterval(+(displayedTimeInterval * 0.5)))
    }

    var body: some View {
        ScrollView {
            VStack {
                GlucoseChart(
                    startTime: start,
                    endTime: end,
                    upperRightLabel: dateStr,
                    chartUnitOffset: $scrollCoordinator.chartUnitOffset,
                    numSegments: numSegments,
                    historicalGlucose: glucoseDataValues,
                    targetRanges: targetRanges
                )
                InsulinDeliveryChart(
                    bolusDoses: boluses,
                    basalDoses: basalDoses,
                    basalSchedule: basalSchedule,
                    startTime: start,
                    endTime: end,
                    chartUnitOffset: $scrollCoordinator.chartUnitOffset,
                    numSegments: numSegments
                )
            }
            .opaqueHorizontalPadding()
        }
        .onPreferenceChange(ScrollableChartDragStatePreferenceKey.self) { dragState in
            scrollCoordinator.dragStateChanged(dragState)
        }
        .onPreferenceChange(ChartInspectionDatePreferenceKey.self) { date in
            inspectionDate = date
        }
        .environment(\.dragStatePublisher, scrollCoordinator.dragStatePublisher)
        .environment(\.chartInspectionDate, inspectionDate)
        .onAppear {
            refreshData()
        }
        .onChange(of: scrollCoordinator.chartUnitOffset) { newValue in
            refreshData()
        }
    }

    func refreshData() {
        Task {
            do {
                print("**** Loading data for offset \(scrollCoordinator.chartUnitOffset)")
                glucoseDataValues = try await dataSource.getGlucoseValues(start: start, end: end)
                targetRanges = try await dataSource.getTargetRanges(start: start, end: end)
                boluses = try await dataSource.getBoluses(start: start, end: end)
                basalSchedule = try await dataSource.getBasalSchedule(start: start, end: end)
                basalDoses = try await dataSource.getBasalDoses(start: start, end: end)
            } catch {
                print("Error refreshing data: \(error)")
            }
        }
    }
}

struct MainChartsView_Previews: PreviewProvider {
    static var dataSource = MockDataSource()

    static var previews: some View {
        BasicChartsView(dataSource: dataSource)
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
