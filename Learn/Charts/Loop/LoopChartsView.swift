//
//  LoopChartsView.swift
//  Learn
//
//  Created by Pete Schwamb on 2/22/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit

struct LoopChartsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ObservedObject private var scrollCoordinator = ChartScrollCoordinator()

    @State private var data = LoopChartsData()

    // When in inspection mode, the date being inspected
    @State private var inspectionDate: Date?

    // This lets us have a more persistent baseTime
    @State private var viewCreationDate = Date()

    // If the user taps on a glucose value, we navigate to a forecast review
    @State private var forecastReviewDate: Date? = nil
    @State private var showingForecastReview: Bool = false

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
            from: scrolledToTime.addingTimeInterval(-(displayedTimeInterval * 0.4)),
            to: scrolledToTime.addingTimeInterval(+(displayedTimeInterval * 0.4)))
    }

    var body: some View {
        VStack {
            LoopGlucoseChart(
                startTime: start,
                endTime: end,
                historicalGlucose: data.glucose,
                targetRanges: data.targetRanges,
                carbEntries: data.carbEntries,
                manualBoluses: data.manualBoluses,
                upperRightLabel: dateStr,
                chartUnitOffset: $scrollCoordinator.chartUnitOffset,
                numSegments: numSegments) { sample in
                    print("Here")
                    forecastReviewDate = sample.startDate
                    showingForecastReview = true
                }
            ActiveInsulinChart(
                startTime: start,
                endTime: end,
                activeInsulin: data.insulinOnBoard,
                chartUnitOffset: $scrollCoordinator.chartUnitOffset,
                numSegments: numSegments
            )
            InsulinDosesChart(
                startTime: start,
                endTime: end,
                doses: data.doses,
                basalHistory: data.basalHistory,
                chartUnitOffset: $scrollCoordinator.chartUnitOffset,
                numSegments: numSegments,
                basalEndTime: dataSource.endOfData
            )
            ActiveCarbohydratesChart(
                startTime: start,
                endTime: end,
                activeCarbs: data.activeCarbs,
                chartUnitOffset: $scrollCoordinator.chartUnitOffset,
                numSegments: numSegments
            )
            NavigationLink(
                isActive: $showingForecastReview,
                destination: { ForecastReview(dataSource: dataSource, initialBaseTime: forecastReviewDate) },
                label: { EmptyView() } )
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
                self.data = try await LoopAlgorithm.fetchLoopChartsData(dataSource: dataSource, interval: interval)
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
            LoopChartsView(dataSource: dataSource)
                .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
        }
    }
}
