//
//  ChartScrollCoordinator.swift
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
class ChartScrollCoordinator: ObservableObject {

    @Published var chartUnitOffset: Int = 0

    private let chartDragStateSubject = PassthroughSubject<ScrollableChartDragState, Never>()

    var dragStatePublisher: AnyPublisher<ScrollableChartDragState, Never> {
        return chartDragStateSubject.eraseToAnyPublisher()
    }

    func dragStateChanged(_ state: ScrollableChartDragState) {
        switch state {
        case .dragging:
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
}

