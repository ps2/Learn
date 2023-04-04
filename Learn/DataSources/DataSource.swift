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

protocol DataSource: AnyObject, ObservableObject {
    typealias RawStateValue = [String: Any]

    static var localizedTitle: String { get }
    static var dataSourceTypeIdentifier: String { get }

    var dataSourceInstanceIdentifier: String { get }

    var loadingStatePublisher: Published<LoadingState>.Publisher { get }

    var name: String { get }

    init?(rawState: RawStateValue)

    /// The current, serializable state of the data source
    var rawState: RawStateValue { get }

    static func setupView(didSetupDataSource: @escaping (any DataSource) -> Void) -> AnyView

    var summaryView: AnyView { get }

    // Data fetching apis

    // If current data is not expected, return the last available date
    var endOfData: Date? { get }

    func getGlucoseSamples(start: Date, end: Date, completion: @escaping (Result<[StoredGlucoseSample], Error>) -> Void)
    func getHistoricSettings(start: Date, end: Date, completion: @escaping (Result<[StoredSettings], Error>) -> Void)
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
