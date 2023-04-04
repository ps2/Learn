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


class BasicChartsViewModel: ObservableObject {

    @Published var loadingState: LoadingState

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

    @Published var chartUnitOffset: Int = 0 {
        didSet {
            refreshData()
        }
    }

    @Published var glucoseDataValues: [GlucoseValue] = []
    @Published var insulinDataValues: [InsulinValue] = []
    @Published var targetRanges: [TargetRange] = []

    // When in inspection mode, the date being inspected
    @Published var inspectionDate: Date?

    private let chartDragStateSubject = PassthroughSubject<ScrollableChartDragState, Never>()

    var dragStatePublisher: AnyPublisher<ScrollableChartDragState, Never> {
        return chartDragStateSubject.eraseToAnyPublisher()
    }

    private var dataSource: any DataSource
    private var insulinData = InsulinData()

    let displayUnits: HKUnit

    private var cancellables: Set<AnyCancellable> = []

    init(dataSource: any DataSource, displayUnits: HKUnit, displayedTimeInterval: TimeInterval) {
        self.dataSource = dataSource
        self.displayUnits = displayUnits
        self.displayedTimeInterval = displayedTimeInterval
        self.loadingState = .isLoading

        dataSource.loadingStatePublisher
            .receive(on: RunLoop.main)
            .sink { (newState) in
                self.loadingState = newState
            }.store(in: &cancellables)
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

    func refreshData() {

        // Glucose
        dataSource.getGlucoseSamples(start: start, end: end) { result in
            switch result {
            case .success(let samples):
                DispatchQueue.main.async {
                    self.glucoseDataValues = samples.map({ sample in
                        GlucoseValue(value: sample.quantity.doubleValue(for: self.displayUnits), date: sample.startDate)
                    })
                }
            case .failure(let error):
                print("Error fetching glucose: \(error)")
            }
        }

        // Target Schedule
        dataSource.getHistoricSettings(start: start, end: end) { result in
            switch result {
            case .success(let settings):
                DispatchQueue.main.async {
                    if let latestSetting = settings.sorted(by: { $0.date < $1.date }).last,
                       let schedule = latestSetting.glucoseTargetRangeSchedule {
                        self.targetRanges = schedule.quantityBetween(start: self.start, end: self.end).compactMap { entry in
                            let range = entry.value.doubleRange(for: self.displayUnits)
                            return TargetRange(range: range, startTime: entry.startDate, endTime: entry.endDate)
                        }
                    }
                }
            case .failure(let error):
                print("Error fetching historic settings: \(error)")
            }
        }

        // Insulin
        insulinDataValues = insulinData.fetchData(startDate: start, endDate: end)

    }
}

