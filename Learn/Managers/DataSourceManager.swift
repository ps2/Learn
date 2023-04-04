//
//  DataSourceManager.swift
//  Learn
//
//  Created by Pete Schwamb on 2/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import os.log

class DataSourceManager: ObservableObject {
    @Published var dataSources: [any DataSource] = []

    private let storageURL: URL

    private let log = OSLog(subsystem: "com.loopkit.Loop", category: "PersistedProperty")

    public init() {
        guard let localDocuments = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            preconditionFailure("Could not get a documents directory URL.")
        }
        storageURL = localDocuments.appendingPathComponent("dataSources")

        do {
            try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        } catch {
            os_log(.error, "Unable to create directory for storing datasources", error.localizedDescription)
        }

        dataSources = loadDataSources()
    }


    let dataSourceTypes: Array<any DataSource.Type> = [NightscoutDataSource.self, IssueReportDataSource.self, MockDataSource.self]

    var dataSourceDescriptions: [DataSourceDescription] {
        dataSourceTypes.map { DataSourceDescription(id: $0.dataSourceTypeIdentifier, localizedTitle: $0.localizedTitle)}
    }

    func dataSourceTypeByIdentifier(identifier: String) -> (any DataSource.Type)? {
        dataSourceTypes.first { $0.dataSourceTypeIdentifier == identifier }
    }

    func persistState(dataSource: any DataSource) {
        let rawValue = dataSource.rawValue
        let path = storageURL.appendingPathComponent(dataSource.dataSourceInstanceIdentifier + ".plist")
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: rawValue, format: .binary, options: 0)
            try data.write(to: path, options: .atomic)
            os_log(.info, "Wrote state to %{public}@", path.absoluteString)
        } catch {
            os_log(.error, "Error saving state: %{public}@", error.localizedDescription)
        }
    }

    func loadDataSources() -> [any DataSource] {
        var sources: [any DataSource] = []
        let enumerator = FileManager.default.enumerator(at: storageURL, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants)
        while let file = enumerator?.nextObject() as? NSURL {
            print("Looking at \(file)")
            do {
                let data = try Data(contentsOf: file as URL)
                os_log(.info, "Reading data source state from %{public}@", storageURL.absoluteString)
                guard let value = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? DataSource.RawValue else {
                    continue
                }
                if let dataSourceTypeIdentifier = value["dataSourceTypeIdentifier"] as? String,
                   let dataSourceState = value["state"] as? DataSource.RawStateValue,
                   let dataSourceType = dataSourceTypeByIdentifier(identifier: dataSourceTypeIdentifier)
                {
                    if let dataSource = dataSourceType.init(rawState: dataSourceState) {
                        print("Instantiated \(dataSourceType)")
                        sources.append(dataSource)
                    }
                } else {
                    os_log(.error, "Unable to determine data source type for: %{public}@", file)
                }
            } catch {
                os_log(.error, "Error reading data source state: %{public}@", error.localizedDescription)
            }
        }
        return sources
    }

    func addDataSource(dataSource: any DataSource) {
        persistState(dataSource: dataSource)
        dataSources.append(dataSource)
    }
}
