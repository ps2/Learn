//
//  PropertyListStateStorage.swift
//  Learn
//
//  Created by Pete Schwamb on 6/5/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import os.log

struct PropertyListStateStorage: StateStorage {
    private let log = OSLog(subsystem: "org.loopkit.Learn", category: "PropertyListStateStorage")

    let typeIdentifier: String
    let instanceIdentifier: String
    let storageURL: URL

    var path: URL {
        storageURL.appendingPathComponent(instanceIdentifier + ".plist")
    }

    func store(rawState: DataSource.RawStateValue) {
        do {
            let wrapped: [String : Any] = [
                "dataSourceTypeIdentifier": typeIdentifier,
                "dataSourceInstanceIdentifier": instanceIdentifier,
                "state": rawState
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: wrapped, format: .binary, options: 0)
            try data.write(to: path, options: .atomic)
            log.info("Wrote state to %{public}@", path.absoluteString)
        } catch {
            log.error("Error saving state: %{public}@", error.localizedDescription)
        }
    }

    func remove() throws {
        try FileManager.default.removeItem(at: path)
    }
}
