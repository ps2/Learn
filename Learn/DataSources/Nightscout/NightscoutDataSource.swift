//
//  NightscoutDataSource.swift
//  Learn
//
//  Created by Pete Schwamb on 2/20/23.
//

import Foundation
import LoopKit
import NightscoutKit
import SwiftUI

final class NightscoutDataSource: DataSource {

    static var localizedTitle: String = "Nightscout"
    static var dataSourceTypeIdentifier: String = "nightscout"

    var dataSourceInstanceIdentifier: String

    typealias RawValue = [String: Any]
    let nightscoutClient: NightscoutClient

    let name: String
    var url: URL
    var apiSecret: String?

    init(name: String, url: URL, apiSecret: String? = nil, instanceIdentifier: String? = nil) {
        self.name = name
        self.url = url
        self.apiSecret = apiSecret
        self.dataSourceInstanceIdentifier = instanceIdentifier ?? UUID().uuidString
        nightscoutClient = NightscoutClient(siteURL: url, apiSecret: apiSecret)
    }

    convenience init?(rawState: RawStateValue) {
        guard let name = rawState["name"] as? String,
              let urlStr = rawState["url"] as? String,
              let instanceIdentifier = rawState["instanceIdentifier"] as? String,
              let url = URL(string: urlStr)
        else
        {
            return nil
        }

        let apiSecret = rawState["apiSecret"] as? String

        self.init(name: name, url: url, apiSecret: apiSecret, instanceIdentifier: instanceIdentifier)
    }

    var rawState: RawStateValue {
        var raw = [
            "name": name,
            "url": url.absoluteString,
            "instanceIdentifier": dataSourceInstanceIdentifier
        ]
        raw["apiSecret"] = apiSecret
        return raw
    }

    static func setupView(didSetupDataSource: @escaping (any DataSource) -> Void) -> AnyView {
        let configurationChecker = NightscoutConfigurationChecker()
        return AnyView(NightscoutSetupView(configurationChecker: configurationChecker, didFinishSetup: { url, nickname, apiSecret in
            let dataSource = NightscoutDataSource(name: nickname, url: url, apiSecret: apiSecret)
            didSetupDataSource(dataSource)
        }))
    }

    var summaryView: AnyView {
        return AnyView(NightscoutSummaryView(name: name))
    }

    var endOfData: Date? {
        return nil
    }

    public func getGlucoseSamples(start: Date, end: Date, completion: @escaping (_ result: Result<[StoredGlucoseSample], Error>) -> Void) {
        let interval = DateInterval(start: start, end: end)

        print("Fetching \(interval)")

        nightscoutClient.fetchGlucose(dateInterval: interval, maxCount: 1000) { result in
            switch result {
            case .failure(let error):
                print("Failed to fetch glucose: \(error)")
                completion(.failure(error))
            case .success(let entries):
                let samples = entries.map { $0.storedGlucoseSample }
                completion(.success(samples))
            }
        }
    }

    public func getHistoricSettings(start: Date, end: Date, completion: @escaping (Result<[StoredSettings], Error>) -> Void) {
        let interval = DateInterval(start: start, end: end)

        nightscoutClient.fetchProfiles(dateInterval: interval) { result in
            switch result {
            case .failure(let error):
                print("Failed to fetch settings: \(error)")
                completion(.failure(error))
            case .success(let entries):
                let samples = entries.compactMap { $0.storedSettings }
                completion(.success(samples))
            }
        }
    }
}


