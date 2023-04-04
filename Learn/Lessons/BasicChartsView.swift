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

    init(viewModel: BasicChartsViewModel) {
        self.viewModel = viewModel
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
                        chartUnitOffset: $viewModel.chartUnitOffset,
                        numSegments: viewModel.numSegments,
                        historicalGlucose: viewModel.glucoseDataValues,
                        targetRanges: viewModel.targetRanges
                    )
                    InsulinChart(
                        data: viewModel.insulinDataValues,
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
            viewModel.refreshData()
        }
    }
}

struct MainChartsView_Previews: PreviewProvider {
    static var previews: some View {
        BasicChartsView(viewModel: BasicChartsViewModel(dataSource: MockDataSource(), displayUnits: .milligramsPerDeciliter, displayedTimeInterval: TimeInterval(hours: 6)))
    }
}
