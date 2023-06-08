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

    @Published var loadingState: LoadingState = .isLoading

    typealias RawValue = [String: Any]
    let nightscoutClient: NightscoutClient

    let name: String
    var url: URL
    var apiSecret: String?
    var cacheEndDate: Date?
    var stateStorage: StateStorage?

    private var manager: NightscoutDataManager

    init(name: String, url: URL, apiSecret: String? = nil, instanceIdentifier: String? = nil, cacheEndDate: Date = .distantPast) {
        self.name = name
        self.url = url
        self.apiSecret = apiSecret
        self.dataSourceInstanceIdentifier = instanceIdentifier ?? UUID().uuidString
        self.cacheEndDate = cacheEndDate
        nightscoutClient = NightscoutClient(siteURL: url, apiSecret: apiSecret)
        manager = NightscoutDataManager(instanceIdentifier: self.dataSourceInstanceIdentifier, nightscoutClient: nightscoutClient, cacheEndDate: cacheEndDate)

        Task { @MainActor in
            await manager.setDelegate(self)
            self.loadingState = .isLoading
            await manager.syncRemoteData()
            self.loadingState = .ready
        }
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

        let cacheEndDate = rawState["cacheEndDate"] as? Date ?? .distantPast

        self.init(name: name, url: url, apiSecret: apiSecret, instanceIdentifier: instanceIdentifier, cacheEndDate: cacheEndDate)
    }

    var rawState: RawStateValue {
        var raw: RawValue = [
            "name": name,
            "url": url.absoluteString,
            "instanceIdentifier": dataSourceInstanceIdentifier,
        ]
        raw["apiSecret"] = apiSecret
        raw["cacheEndDate"] = cacheEndDate
        return raw
    }

    @MainActor static func setupView(didSetupDataSource: @escaping (any DataSource) -> Void) -> AnyView {
        let configurationChecker = NightscoutConfigurationChecker()
        return AnyView(NightscoutSetupView(configurationChecker: configurationChecker, didFinishSetup: { url, nickname, apiSecret in
            let dataSource = NightscoutDataSource(name: nickname, url: url, apiSecret: apiSecret)
            didSetupDataSource(dataSource)
        }))
    }

    var summaryView: AnyView {
        AnyView(NightscoutSummaryView(name: name))
    }

    var mainView: AnyView {
        AnyView(NightscoutMainView(dataSource: self))
    }

    var endOfData: Date? {
        return nil
    }

    func getGlucoseSamples(start: Date, end: Date) async throws -> [StoredGlucoseSample] {
        return try await manager.getGlucoseSamples(start: start, end: end)
    }

    func getHistoricSettings(start: Date, end: Date) async throws -> [StoredSettings] {
        return []
    }

}

extension NightscoutDataSource: NightscoutDataManagerDelegate {
    func didUpdateCache(cacheEndDate: Date) {
        DispatchQueue.main.async {
            self.cacheEndDate = cacheEndDate
            self.stateStorage?.store(rawState: self.rawState)
        }
    }
}


