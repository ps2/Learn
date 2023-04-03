//
//  ScrollableChart.swift
//  Learn
//
//  Created by Pete Schwamb on 1/8/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import Combine

struct ScrollableChartDragStatePreferenceKey: PreferenceKey {
    static let defaultValue: ScrollableChartDragState = .inactive

    static func reduce(value: inout ScrollableChartDragState, nextValue: () -> ScrollableChartDragState) {
        let n = nextValue()
        if n != .inactive {
            value = n
        }
    }
}

private struct ScrollableChartDragPublisherKey: EnvironmentKey {
    static let defaultValue: AnyPublisher<ScrollableChartDragState, Never> = Empty(completeImmediately: false).eraseToAnyPublisher()
}

public extension EnvironmentValues {
    var dragStatePublisher: AnyPublisher<ScrollableChartDragState, Never> {
        get { self[ScrollableChartDragPublisherKey.self] }
        set { self[ScrollableChartDragPublisherKey.self] = newValue }
    }
}

public struct ScrollableChartSettleParameters: Equatable {
    let startOffset: CGFloat
    let endOffset: CGFloat
    let endUnit: Int
    let animationDuration: TimeInterval
}

public enum ScrollableChartDragState: Equatable {
    case dragging(offset: CGFloat)
    case settling(parameters: ScrollableChartSettleParameters)
    case inactive
}

struct ScrollableChart<Content: View, YAxis: View>: View {
    private let height: CGFloat
    private let numSegments: Int
    private let pagingAnimationDuration: CGFloat = 0.2

    var dragState: ScrollableChartDragState {
        if let dragOffset {
            return .dragging(offset: dragOffset)
        } else if let settleParameters {
            return .settling(parameters: settleParameters)
        } else {
            return .inactive
        }
    }

    @Environment(\.dragStatePublisher) private var dragStatePublisher

    // Tracks the drag offset
    @GestureState private var dragOffset: CGFloat?

    // Translation offset for the chart within this view
    @State private var translationOffset: CGFloat = .zero

    // Translation offset used during ending animation where we settle to final unit/page
    @State private var settleOffsetAnimatable: CGFloat?

    @State private var settleParameters: ScrollableChartSettleParameters?

    // Width of the yAxis of chart
    @State private var yAxisWidth: CGFloat = .zero

    // Each bar represents a unit duration along xAxis
    @Binding var chartUnitOffset: Int

    private var cancellables: Set<AnyCancellable> = []

    @Environment(\.locale) var locale

    private var chart: Content
    private var yAxis: any View

    init(yAxis: YAxis, chartUnitOffset: Binding<Int>, height: CGFloat, numSegments: Int, chart: () -> Content) {
        self._chartUnitOffset = chartUnitOffset
        self.yAxis = yAxis
            .chartPlotStyle { plot in
                plot.frame(width: 0)
            }
        self.chart = chart()
        self.height = height
        self.numSegments = numSegments
    }

    private func drag(chartWidth: Double) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, tx in
                state = value.translation.width
            }
            .onEnded { value in
                let settleStart = value.translation.width

                let unitWidth = chartWidth / Double(numSegments)
                let unitOffset = (value.translation.width / unitWidth).rounded(.toNearestOrAwayFromZero)
                var predictedUnitOffset = (value.predictedEndTranslation.width / unitWidth).rounded(.toNearestOrAwayFromZero)

                // If swipe carefully, change to the nearest time unit
                // If swipe fast enough, change to the next page
                predictedUnitOffset = max(-Double(numSegments), predictedUnitOffset)
                predictedUnitOffset = min(Double(numSegments), predictedUnitOffset)
                let settleEnd: CGFloat
                if abs(predictedUnitOffset) >= Double(numSegments) {
                    settleEnd = predictedUnitOffset * unitWidth
                } else {
                    settleEnd = unitOffset * unitWidth
                }

                let settledUnitOffset = chartUnitOffset - Int(settleEnd / unitWidth)

                settleParameters = ScrollableChartSettleParameters(
                    startOffset: settleStart,
                    endOffset: settleEnd,
                    endUnit: settledUnitOffset,
                    animationDuration: pagingAnimationDuration)
            }
    }

    var getTranslationOffset: CGFloat {
        //print("Using translationOffset: \(translationOffset)")
        return translationOffset
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Put the yAxis above the graph, as clipping the graph is proving problematic
            AnyView(yAxis)
                .background(.background)
                .zIndex(10)
            GeometryReader { geometry in
                chart
                    // The actual width of the plot area is three times of page width
                    .frame(width: geometry.size.width * 3, height: geometry.size.height)
                    .offset(x: getTranslationOffset + (settleOffsetAnimatable ?? 0) - geometry.size.width)
                    .gesture(drag(chartWidth: geometry.size.width))
            }
            //.clipped()
        }
        .preference(key: ScrollableChartDragStatePreferenceKey.self, value: dragState)
        .onReceive(dragStatePublisher) { dragState in
            //print("Receive dragState: \(dragState)")
            switch dragState {
            case .dragging(let offset):
                self.translationOffset = offset
            case .settling(let parameters):
                translationOffset = 0
                settleOffsetAnimatable = parameters.startOffset
                withAnimation(.easeOut(duration: parameters.animationDuration)) {
                    settleOffsetAnimatable = parameters.endOffset
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + parameters.animationDuration) {
                    settleParameters = nil
                    settleOffsetAnimatable = nil
                }

            case .inactive:
                self.translationOffset = 0
            }
        }
        .frame(height: height)
    }
}
