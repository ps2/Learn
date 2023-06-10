//
//  DataSource.swift
//  Learn
//
//  Created by Pete Schwamb on 2/20/23.
//

import Foundation
import SwiftUI
import LoopKit

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
    func getGlucoseValues(start: Date, end: Date) async throws -> [GlucoseValue]
    func getTargetRanges(start: Date, end: Date) async throws -> [TargetRange]
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