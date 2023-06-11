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

    func getGlucoseValues(start: Date, end: Date) async throws -> [GlucoseValue] {
        return try await manager.getGlucoseSamples(start: start, end: end).map { GlucoseValue(quantity: $0.quantity, date: $0.startDate) }
    }

    func getTargetRanges(start: Date, end: Date) async throws -> [TargetRange] {
        return []
    }

    func getBasalDoses(start: Date, end: Date) async throws -> [Basal] {
        return []
    }

    func getBasalSchedule(start: Date, end: Date) async throws -> [ScheduledBasal] {
        // Get any changes during the period
        var settingsHistory = try await manager.settingsStore.getStoredSettings(start: start, end: end)

        // Also need to get the one in effect before the start of the period
        if let firstSettings = try await manager.settingsStore.getStoredSettings(end: start, limit: 1).first {
            settingsHistory.append(firstSettings)
        }

        guard !settingsHistory.isEmpty else {
            return []
        }

        // Order from oldest to newest
        settingsHistory.reverse()

        // Find all valid, non-repeat basal rate schedules in settings
        var lastSchedule: BasalRateSchedule? = nil
        let schedules: [(date: Date, schedule: BasalRateSchedule)] = settingsHistory.compactMap { settings in
            if let schedule = settings.basalRateSchedule, schedule != lastSchedule {
                lastSchedule = schedule
                return (date: settings.date, schedule: schedule)
            } else {
                return nil
            }
        }

        var idx = schedules.startIndex
        var date = start
        var items = [ScheduledBasal]()
        while date < end {
            let scheduleActiveEnd: Date
            if idx+1 < schedules.endIndex {
                scheduleActiveEnd = schedules[idx+1].date
            } else {
                scheduleActiveEnd = end
            }

            let schedule = schedules[idx].schedule

            let absoluteScheduleValues = schedule.truncatingBetween(start: date, end: scheduleActiveEnd)

            items.append(contentsOf: absoluteScheduleValues.map { ScheduledBasal(start: $0.startDate, end: $0.endDate, rate: $0.value) } )
            date = scheduleActiveEnd
            idx += 1
        }


        return items
    }

    func getBoluses(start: Date, end: Date) async throws -> [Bolus] {
        return try await manager.doseStore.getBoluses(start: start, end: end).map { dose in
            Bolus(date: dose.startDate, amount: dose.deliveredUnits ?? dose.programmedUnits, automatic: dose.automatic ?? false, id: dose.syncIdentifier ?? UUID().uuidString)
        }
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


