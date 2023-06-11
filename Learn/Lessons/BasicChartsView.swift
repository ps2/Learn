//
//  BasicChartsView.swift
//  Learn
//
//  Created by Pete Schwamb on 2/22/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct BasicChartsView: View {
    @ObservedObject private var viewModel: BasicChartsViewModel

    @State var glucoseDataValues: [GlucoseValue] = []
    @State var targetRanges: [TargetRange] = []
    @State var boluses: [Bolus] = []
    @State var basalSchedule: [ScheduledBasal] = []
    @State var basalDoses: [Basal] = []


    private var dataSource: any DataSource

    init(viewModel: BasicChartsViewModel, dataSource: any DataSource) {
        self.viewModel = viewModel
        self.dataSource = dataSource
    }

    var isLoading: Bool {
        if case .isLoading = viewModel.loadingState {
            return true
        }
        return false
    }

    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(4)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .center
                        )

                }
            } else {
                VStack {
                    GlucoseChart(
                        startTime: viewModel.start,
                        endTime: viewModel.end,
                        upperRightLabel: viewModel.dateStr,
                        chartUnitOffset: $viewModel.chartUnitOffset,
                        numSegments: viewModel.numSegments,
                        historicalGlucose: glucoseDataValues,
                        targetRanges: targetRanges
                    )
                    InsulinDeliveryChart(
                        bolusDoses: boluses,
                        basalDoses: basalDoses,
                        basalSchedule: basalSchedule,
                        startTime: viewModel.start,
                        endTime: viewModel.end,
                        chartUnitOffset: $viewModel.chartUnitOffset,
                        numSegments: viewModel.numSegments
                    )
                }
                .opaqueHorizontalPadding()
            }
        }
        .onPreferenceChange(ScrollableChartDragStatePreferenceKey.self) { dragState in
            viewModel.dragStateChanged(dragState)
        }
        .onPreferenceChange(ChartInspectionDatePreferenceKey.self) { date in
            viewModel.inspectionDate = date
        }
        .environment(\.dragStatePublisher, viewModel.dragStatePublisher)
        .environment(\.chartInspectionDate, viewModel.inspectionDate)
        .onAppear {
            refreshData()
        }
        .onChange(of: viewModel.chartUnitOffset) { newValue in
            refreshData()
        }
    }

    func refreshData() {
        Task {
            do {
                print("**** Loading data for offset \(viewModel.chartUnitOffset)")
                glucoseDataValues = try await dataSource.getGlucoseValues(start: viewModel.start, end: viewModel.end)
                targetRanges = try await dataSource.getTargetRanges(start: viewModel.start, end: viewModel.end)
                boluses = try await dataSource.getBoluses(start: viewModel.start, end: viewModel.end)
                basalSchedule = try await dataSource.getBasalSchedule(start: viewModel.start, end: viewModel.end)
                basalDoses = try await dataSource.getBasalDoses(start: viewModel.start, end: viewModel.end)
            } catch {
                print("Error refreshing data: \(error)")
            }
        }
    }
}

struct MainChartsView_Previews: PreviewProvider {
    static var dataSource = MockDataSource()

    static var previews: some View {
        BasicChartsView(viewModel: BasicChartsViewModel(displayedTimeInterval: TimeInterval(hours: 6)), dataSource: dataSource)
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
