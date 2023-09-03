//
//  BasicChartsView.swift
//  Learn
//
//  Created by Pete Schwamb on 2/22/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit

struct BasicChartsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ObservedObject private var scrollCoordinator = ChartScrollCoordinator()

    @State private var glucoseDataValues: [GlucoseSampleValue] = []
    @State private var targetRanges: [AbsoluteScheduleValue<ClosedRange<HKQuantity>>] = []
    @State private var basalHistory: [AbsoluteScheduleValue<Double>] = []
    @State private var doses: [DoseEntry] = []
    @State private var carbEntries: [CarbEntry] = []
    @State private var insulinOnBoard: [InsulinValue] = []

    // When in inspection mode, the date being inspected
    @State private var inspectionDate: Date?

    // This lets us have a more persistent baseTime
    @State private var viewCreationDate = Date()

    var baseTime: Date {
        return (dataSource.endOfData ?? viewCreationDate).roundDownToHour()
    }

    private var dataSource: any DataSource

    init(dataSource: any DataSource) {
        self.dataSource = dataSource
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
        VStack {
            GlucoseChart(
                startTime: start,
                endTime: end,
                historicalGlucose: glucoseDataValues,
                targetRanges: targetRanges,
                carbEntries: carbEntries,
                upperRightLabel: dateStr,
                chartUnitOffset: $scrollCoordinator.chartUnitOffset,
                numSegments: numSegments
            )
            ActiveInsulinChart(
                startTime: start,
                endTime: end,
                activeInsulin: insulinOnBoard,
                chartUnitOffset: $scrollCoordinator.chartUnitOffset,
                numSegments: numSegments
            )
            InsulinDosesChart(
                startTime: start,
                endTime: end,
                doses: doses,
                basalHistory: basalHistory,
                chartUnitOffset: $scrollCoordinator.chartUnitOffset,
                numSegments: numSegments
            )

        }
        .opaqueHorizontalPadding()
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
        .onChange(of: baseTime) { newValue in
            refreshData()
        }
    }

    func refreshData() {
        Task {
            do {
                let interval = DateInterval(start: start, end: end)
                await dataSource.syncData(interval: interval)
                glucoseDataValues = try await dataSource.getGlucoseValues(interval: interval)
                targetRanges = try await dataSource.getTargetRangeHistory(interval: interval)
                basalHistory = try await dataSource.getBasalHistory(interval: interval)
                let iobDoseInterval = DateInterval(start: start.addingTimeInterval(-InsulinMath.defaultInsulinActivityDuration), end: end)
                let historicDoses = try await dataSource.getDoses(interval: iobDoseInterval)
                insulinOnBoard = historicDoses.insulinOnBoard()
                doses = historicDoses.filterDateInterval(interval: interval)
                carbEntries = try await dataSource.getCarbEntries(interval: interval)
            } catch {
                print("Error refreshing data: \(error)")
            }
        }
    }
}

struct MainChartsView_Previews: PreviewProvider {
    static var dataSource = MockDataSource()

    static var previews: some View {
        ScrollView {
            BasicChartsView(dataSource: dataSource)
                .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
        }
    }
}
