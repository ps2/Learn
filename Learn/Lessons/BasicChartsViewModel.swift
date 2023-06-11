//
//  BasicChartsViewModel.swift
//  Learn
//
//  Created by Pete Schwamb on 1/15/23.
//

import Foundation
import SwiftUI
import Combine
import HealthKit
import LoopKit


@MainActor
class BasicChartsViewModel: ObservableObject {

    @Published var loadingState: LoadingState = .ready

    let baseTime: Date

    private var displayedTimeInterval: TimeInterval
    private var segmentSize = TimeInterval(hours: 1) // Panning "snaps" to these segments

    var numSegments: Int {
        return Int((displayedTimeInterval / segmentSize).rounded())
    }

    private var scrolledToTime: Date {
        return baseTime.addingTimeInterval(segmentSize * Double(chartUnitOffset))
    }

    var start: Date {
        return scrolledToTime.addingTimeInterval(-(displayedTimeInterval * 1.5))
    }

    var end: Date {
        return scrolledToTime.addingTimeInterval(displayedTimeInterval * 1.5)
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

    @Published var chartUnitOffset: Int = 0 {
        didSet {
            Task {
                await loadData()
            }
        }
    }

    // When in inspection mode, the date being inspected
    @Published var inspectionDate: Date?

    private let chartDragStateSubject = PassthroughSubject<ScrollableChartDragState, Never>()

    var dragStatePublisher: AnyPublisher<ScrollableChartDragState, Never> {
        return chartDragStateSubject.eraseToAnyPublisher()
    }

    private var cancellables: Set<AnyCancellable> = []

    init(initialFocusDate: Date? = nil, displayedTimeInterval: TimeInterval) {
        self.displayedTimeInterval = displayedTimeInterval

        baseTime = (initialFocusDate ?? Date()).roundDownToHour()!
    }

    func dragStateChanged(_ state: ScrollableChartDragState) {
        switch state {
        case .dragging:
            //print("Dragging state: \(state)")
            chartDragStateSubject.send(state)
        case .settling(let parameters):
            chartDragStateSubject.send(state)
            DispatchQueue.main.asyncAfter(deadline: .now() + parameters.animationDuration) {
                self.chartUnitOffset = parameters.endUnit
            }
        default:
            break
        }
    }

    func loadData() async {

        // Glucose
    }
}

