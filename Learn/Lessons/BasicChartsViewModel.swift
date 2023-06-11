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

    var baseTime: Date {
        return (dataSource.endOfData ?? Date()).roundDownToHour()!
    }

    var displayedTimeInterval: TimeInterval
    var segmentSize = TimeInterval(hours: 1) // Panning "snaps" to these segments

    var numSegments: Int {
        return Int((displayedTimeInterval / segmentSize).rounded())
    }

    var scrolledToTime: Date {
        return baseTime.addingTimeInterval(segmentSize * Double(chartUnitOffset))
    }

    var start: Date {
        return scrolledToTime.addingTimeInterval(-(displayedTimeInterval * 1.5))
    }

    var end: Date {
        return scrolledToTime.addingTimeInterval(displayedTimeInterval * 1.5)
    }

    var timeRange: ClosedRange<Date> {
        return start...end
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

    @Published var glucoseDataValues: [GlucoseValue] = []
    @Published var targetRanges: [TargetRange] = []
    @Published var boluses: [Bolus] = []
    @Published var basalSchedule: [ScheduledBasal] = []
    @Published var basalDoses: [Basal] = []

    // When in inspection mode, the date being inspected
    @Published var inspectionDate: Date?

    private let chartDragStateSubject = PassthroughSubject<ScrollableChartDragState, Never>()

    var dragStatePublisher: AnyPublisher<ScrollableChartDragState, Never> {
        return chartDragStateSubject.eraseToAnyPublisher()
    }

    private var dataSource: any DataSource

    private var cancellables: Set<AnyCancellable> = []

    init(dataSource: any DataSource, displayedTimeInterval: TimeInterval) {
        self.dataSource = dataSource
        self.displayedTimeInterval = displayedTimeInterval
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
        do {
            self.glucoseDataValues = try await dataSource.getGlucoseValues(start: start, end: end)
            self.targetRanges = try await dataSource.getTargetRanges(start: start, end: end)
            self.boluses = try await dataSource.getBoluses(start: start, end: end)
            self.basalSchedule = try await dataSource.getBasalSchedule(start: start, end: end)
            self.basalDoses = try await dataSource.getBasalDoses(start: start, end: end)
        } catch {
            print("Error refreshing data: \(error)")
        }

    }
}

