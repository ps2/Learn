//
//  DataSource.swift
//  Learn
//
//  Created by Pete Schwamb on 2/20/23.
//

import Foundation
import SwiftUI
import LoopKit
import HealthKit
import LoopAlgorithm

enum LoadingState: Equatable {
    static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.isLoading, .isLoading):
            return true
        case (.ready, .ready):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return String(describing: lhsError) == String(describing: rhsError)
        default:
            return false
        }
    }

    case isLoading
    case failed(Error)
    case ready
}

protocol StateStorage {
    func store(rawState: DataSource.RawStateValue)
    func remove() throws
}

struct DosingLimits {
    var suspendThreshold: HKQuantity?
    var maxBolus: Double?
    var maxBasalRate: Double?
}

protocol DataSource: AnyObject, ObservableObject, Identifiable {
    typealias RawStateValue = [String: Any]

    static var localizedTitle: String { get }
    static var dataSourceTypeIdentifier: String { get }

    var dataSourceInstanceIdentifier: String { get }

    var name: String { get }

    var stateStorage: StateStorage? { get set }

    init?(rawState: RawStateValue)

    /// The current, serializable state of the data source
    var rawState: RawStateValue { get }

    static func setupView(didSetupDataSource: @escaping (any DataSource) -> Void) -> AnyView

    var summaryView: AnyView { get }

    var mainView: AnyView { get }

    // If current data is not expected, return the last available date
    var endOfData: Date? { get }

    // Data fetching apis
    func syncData(interval: DateInterval) async

    // Base diabetes data
    func getGlucoseValues(interval: DateInterval) async throws -> [StoredGlucoseSample]
    func getDoses(interval: DateInterval) async throws -> [DoseEntry]
    func getCarbEntries(interval: DateInterval) async throws -> [StoredCarbEntry]

    // Algorithm settings
    func getTargetRangeHistory(interval: DateInterval) async throws -> [AbsoluteScheduleValue<ClosedRange<HKQuantity>>]
    func getBasalHistory(interval: DateInterval) async throws -> [AbsoluteScheduleValue<Double>]
    func getCarbRatioHistory(interval: DateInterval) async throws -> [AbsoluteScheduleValue<Double>]
    func getInsulinSensitivityHistory(interval: DateInterval) async throws -> [AbsoluteScheduleValue<HKQuantity>]
    func getDosingLimits(at: Date) async throws -> DosingLimits
}

extension DataSource {
    typealias RawValue = [String: Any]

    var rawValue: RawValue {
        return [
            "dataSourceTypeIdentifier": Self.dataSourceTypeIdentifier,
            "state": self.rawState
        ]
    }
}
