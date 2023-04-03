//
//  DataSource.swift
//  Learn
//
//  Created by Pete Schwamb on 2/20/23.
//

import Foundation
import SwiftUI
import LoopKit

protocol DataSource: AnyObject {
    typealias RawStateValue = [String: Any]

    static var name: String { get }
    static var dataSourceTypeIdentifier: String { get }

    var dataSourceInstanceIdentifier: String { get }

    var name: String { get }

    init?(rawState: RawStateValue)

    /// The current, serializable state of the data source
    var rawState: RawStateValue { get }

    static func setupView(didSetupDataSource: @escaping (any DataSource) -> Void) -> AnyView

    var summaryView: AnyView { get }

    // Data fetching apis
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
