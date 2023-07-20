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
import HealthKit

final class NightscoutDataSource: DataSource {
    static var localizedTitle: String = "Nightscout"
    static var dataSourceTypeIdentifier: String = "nightscout"

    var dataSourceInstanceIdentifier: String

    typealias RawValue = [String: Any]
    let nightscoutClient: NightscoutClient

    let name: String
    var url: URL
    var apiSecret: String?
    var cacheCoverage: DateInterval?
    var stateStorage: StateStorage?

    private var cache: NightscoutDataCache

    init(name: String, url: URL, apiSecret: String? = nil, instanceIdentifier: String? = nil, cacheCoverage: DateInterval? = nil) {
        self.name = name
        self.url = url
        self.apiSecret = apiSecret
        self.dataSourceInstanceIdentifier = instanceIdentifier ?? UUID().uuidString
        self.cacheCoverage = cacheCoverage
        nightscoutClient = NightscoutClient(siteURL: url, apiSecret: apiSecret)
        cache = NightscoutDataCache(instanceIdentifier: self.dataSourceInstanceIdentifier, nightscoutClient: nightscoutClient, cacheCoverage: cacheCoverage)

        Task { @MainActor in
            await cache.setDelegate(self)
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

        let cacheCoverage: DateInterval?

        if let cacheStart = rawState["cacheStartDate"] as? Date,
           let cacheEnd = rawState["cacheEndDate"] as? Date
        {
            cacheCoverage = DateInterval(start: cacheStart, end: cacheEnd)
        } else {
            cacheCoverage = nil
        }

        self.init(name: name, url: url, apiSecret: apiSecret, instanceIdentifier: instanceIdentifier, cacheCoverage: cacheCoverage)
    }

    var rawState: RawStateValue {
        var raw: RawValue = [
            "name": name,
            "url": url.absoluteString,
            "instanceIdentifier": dataSourceInstanceIdentifier,
        ]
        raw["apiSecret"] = apiSecret
        raw["cacheStartDate"] = cacheCoverage?.start
        raw["cacheEndDate"] = cacheCoverage?.end
        return raw
    }

    func syncRemoteData() async {
        await cache.syncRemoteData()
    }

    func syncData(interval: DateInterval) async {
        guard let cacheCoverage else {
            await syncRemoteData()
            return
        }

        if cacheCoverage.intersection(with: interval) != interval {
            await syncRemoteData()
        }
    }


    static func setupView(didSetupDataSource: @escaping (any DataSource) -> Void) -> AnyView {
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

    func getGlucoseValues(interval: DateInterval) async throws -> [GlucoseSampleValue] {
        try await cache.glucoseStore.getGlucoseSamples(start: interval.start, end: interval.end)
    }

    func getDoses(interval: DateInterval) async throws -> [DoseEntry] {
        return try await cache.doseStore.getDoses(start: interval.start, end: interval.end)
    }

    func getCarbEntries(interval: DateInterval) async throws -> [CarbEntry] {
        let entries = try await cache.carbStore.getCarbEntries(start: interval.start, end: interval.end)
        return entries.map { CarbEntry(startDate: $0.startDate, absorptionTime: $0.absorptionTime, quantity: $0.quantity) }
    }

    func getTargetRangeHistory(interval: DateInterval) async throws -> [LoopKit.AbsoluteScheduleValue<ClosedRange<HKQuantity>>] {
        // Get any changes during the period
        var settingsHistory = try await cache.settingsStore.getStoredSettings(start: interval.start, end: interval.end)

        // Also need to get the one in effect before the start of the period
        if let firstSettings = try await cache.settingsStore.getStoredSettings(end: interval.start, limit: 1).first {
            settingsHistory.append(firstSettings)
        }

        guard !settingsHistory.isEmpty else {
            return []
        }

        // Order from oldest to newest
        settingsHistory.reverse()

        // Find all valid, non-repeat target schedules in settings
        var lastSchedule: GlucoseRangeSchedule? = nil
        let schedules: [(date: Date, schedule: GlucoseRangeSchedule)] = settingsHistory.compactMap { settings in
            if let schedule = settings.glucoseTargetRangeSchedule, schedule != lastSchedule {
                lastSchedule = schedule
                return (date: settings.date, schedule: schedule)
            } else {
                return nil
            }
        }

        var idx = schedules.startIndex
        var date = interval.start
        var items = [LoopKit.AbsoluteScheduleValue<ClosedRange<HKQuantity>>]()
        while date < interval.end {
            let scheduleActiveEnd: Date
            if idx+1 < schedules.endIndex {
                scheduleActiveEnd = schedules[idx+1].date
            } else {
                scheduleActiveEnd = interval.end
            }

            let schedule = schedules[idx].schedule

            let absoluteScheduleValues = schedule.truncatingBetween(start: date, end: scheduleActiveEnd)

            items.append(contentsOf: absoluteScheduleValues.map { entry in
                let quantityRange = entry.value.quantityRange(for: schedule.unit)
                return AbsoluteScheduleValue(startDate: entry.startDate, endDate: entry.endDate, value: quantityRange)
            })
            date = scheduleActiveEnd
            idx += 1
        }
        return items
    }

    func getBasalHistory(interval: DateInterval) async throws -> [AbsoluteScheduleValue<Double>] {
        // Get any settings changes during the period
        var settingsHistory = try await cache.settingsStore.getStoredSettings(start: interval.start, end: interval.end)

        // Also need to get the one in effect before the start of the period
        if let firstSettings = try await cache.settingsStore.getStoredSettings(end: interval.start, limit: 1).first {
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
        var date = interval.start
        var items = [AbsoluteScheduleValue<Double>]()
        while date < interval.end {
            let scheduleActiveEnd: Date
            if idx+1 < schedules.endIndex {
                scheduleActiveEnd = schedules[idx+1].date
            } else {
                scheduleActiveEnd = interval.end
            }

            let schedule = schedules[idx].schedule

            let absoluteScheduleValues = schedule.truncatingBetween(start: date, end: scheduleActiveEnd)

            items.append(contentsOf: absoluteScheduleValues)
            date = scheduleActiveEnd
            idx += 1
        }

        return items
    }

    func getInsulinSensitivityHistory(interval: DateInterval) async throws -> [AbsoluteScheduleValue<HKQuantity>] {
        // Get any settings changes during the period
        var settingsHistory = try await cache.settingsStore.getStoredSettings(start: interval.start, end: interval.end)

        // Also need to get the one in effect before the start of the period
        if let firstSettings = try await cache.settingsStore.getStoredSettings(end: interval.start, limit: 1).first {
            settingsHistory.append(firstSettings)
        }

        guard !settingsHistory.isEmpty else {
            return []
        }

        // Order from oldest to newest
        settingsHistory.reverse()

        // Find all valid, non-repeat basal rate schedules in settings
        var lastSchedule: InsulinSensitivitySchedule? = nil
        let schedules: [(date: Date, schedule: InsulinSensitivitySchedule)] = settingsHistory.compactMap { settings in
            if let schedule = settings.insulinSensitivitySchedule, schedule != lastSchedule {
                lastSchedule = schedule
                return (date: settings.date, schedule: schedule)
            } else {
                return nil
            }
        }

        var idx = schedules.startIndex
        var date = interval.start
        var items = [AbsoluteScheduleValue<HKQuantity>]()
        while date < interval.end {
            let scheduleActiveEnd: Date
            if idx+1 < schedules.endIndex {
                scheduleActiveEnd = schedules[idx+1].date
            } else {
                scheduleActiveEnd = interval.end
            }

            let schedule: InsulinSensitivitySchedule = schedules[idx].schedule

            let absoluteScheduleValues = schedule.truncatingBetween(start: date, end: scheduleActiveEnd).map {
                AbsoluteScheduleValue(
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    value: HKQuantity(unit: schedule.unit, doubleValue: $0.value))
            }

            items.append(contentsOf: absoluteScheduleValues)
            date = scheduleActiveEnd
            idx += 1
        }

        return items
    }

    func getCarbRatioHistory(interval: DateInterval) async throws -> [LoopKit.AbsoluteScheduleValue<Double>] {
        // Get any settings changes during the period
        var settingsHistory = try await cache.settingsStore.getStoredSettings(start: interval.start, end: interval.end)

        // Also need to get the one in effect before the start of the period
        if let firstSettings = try await cache.settingsStore.getStoredSettings(end: interval.start, limit: 1).first {
            settingsHistory.append(firstSettings)
        }

        guard !settingsHistory.isEmpty else {
            return []
        }

        // Order from oldest to newest
        settingsHistory.reverse()

        // Find all valid, non-repeat basal rate schedules in settings
        var lastSchedule: CarbRatioSchedule? = nil
        let schedules: [(date: Date, schedule: CarbRatioSchedule)] = settingsHistory.compactMap { settings in
            if let schedule = settings.carbRatioSchedule, schedule != lastSchedule {
                lastSchedule = schedule
                return (date: settings.date, schedule: schedule)
            } else {
                return nil
            }
        }

        var idx = schedules.startIndex
        var date = interval.start
        var items = [AbsoluteScheduleValue<Double>]()
        while date < interval.end {
            let scheduleActiveEnd: Date
            if idx+1 < schedules.endIndex {
                scheduleActiveEnd = schedules[idx+1].date
            } else {
                scheduleActiveEnd = interval.end
            }

            let schedule = schedules[idx].schedule

            let absoluteScheduleValues = schedule.truncatingBetween(start: date, end: scheduleActiveEnd)

            items.append(contentsOf: absoluteScheduleValues)
            date = scheduleActiveEnd
            idx += 1
        }

        return items
    }
}

extension NightscoutDataSource: NightscoutDataCacheDelegate {
    func didUpdateCache(coverage: DateInterval) {
        DispatchQueue.main.async {
            self.cacheCoverage = coverage
            self.stateStorage?.store(rawState: self.rawState)
        }
    }
}


