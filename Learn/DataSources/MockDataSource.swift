//
//  MockDataSource.swift
//  Learn
//
//  Created by Pete Schwamb on 2/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import LoopKit

class MockDataSource: DataSource {
    var endOfData: Date? {
        return nil
    }

    func getHistoricSettings(start: Date, end: Date, completion: @escaping (Result<[LoopKit.StoredSettings], Error>) -> Void) {
        completion(.success([]))
    }

    func getGlucoseSamples(start: Date, end: Date, completion: @escaping (Result<[LoopKit.StoredGlucoseSample], Error>) -> Void) {
        completion(.success([]))
    }

    static var localizedTitle: String = "MockDataSource"
    static var dataSourceTypeIdentifier: String = "mockdatasource"

    typealias RawStateValue = [String: Any]

    var name: String = "Example Data Source"

    static func setupView(didSetupDataSource: @escaping (any DataSource) -> Void) -> AnyView {
        AnyView(Text("Hello"))
    }

    var summaryView: AnyView {
        return AnyView(Text("Mock Data"))
    }

    var dataSourceInstanceIdentifier: String

    init() {
        dataSourceInstanceIdentifier = UUID().uuidString
    }

    required init?(rawState: RawStateValue) {
        guard let name = rawState["name"] as? String,
              let instanceIdentifier = rawState["instanceIdentifier"] as? String else
        {
            return nil
        }

        self.name = name
        self.dataSourceInstanceIdentifier = instanceIdentifier
    }

    var rawState: RawStateValue {
        return [
            "name": name,
            "instance": dataSourceInstanceIdentifier
        ]
    }

}
