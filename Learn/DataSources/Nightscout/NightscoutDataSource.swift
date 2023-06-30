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

    func getGlucoseValues(interval: DateInterval) async throws -> [GlucoseValue] {
        let samples = try await cache.glucoseStore.getGlucoseSamples(start: interval.start, end: interval.end)
        return samples.map { GlucoseValue(quantity: $0.quantity, date: $0.startDate) }
    }

    func getTargetRanges(interval: DateInterval) async throws -> [TargetRange] {
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
        var items = [TargetRange]()
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
                return TargetRange(min: quantityRange.lowerBound, max: quantityRange.upperBound, startTime: entry.startDate, endTime: entry.endDate)
            })
            date = scheduleActiveEnd
            idx += 1
        }
        return items
    }

    func getBasalDoses(interval: DateInterval) async throws -> [BasalDose] {
        let doseEntries = try await cache.doseStore.getBasalDoses(start: interval.start, end: interval.end)
        // Loop does not store basal records in NS, so overlay basal segments
        let schedule = try await getBasalSchedule(interval: interval)

        var lastBasalEnd = interval.start
        var insertedScheduleEntries = [ScheduledBasal]()

        for dose in doseEntries {
            // Ignore gaps of < 3 seconds
            if dose.startDate > lastBasalEnd && dose.startDate.timeIntervalSince(lastBasalEnd) > .seconds(3) {
                let trimmedSchedule = schedule.trim(start: lastBasalEnd, end: dose.startDate)
                insertedScheduleEntries.append(contentsOf: trimmedSchedule)
            }
            lastBasalEnd = dose.endDate
        }

        // Do not infer basal past current time
        let scheduledBasalMax = min(interval.end, Date())

        if lastBasalEnd < scheduledBasalMax {
            insertedScheduleEntries.append(contentsOf: schedule.trim(start: lastBasalEnd, end: scheduledBasalMax))
        }

        let insertedDoses = insertedScheduleEntries.map { item in
            BasalDose(
                start: item.start,
                end: item.end,
                rate: item.rate,
                temporary: false,
                automatic: false,
                id: UUID().uuidString)
        }

        var basalDoses = doseEntries.map { dose in
            return BasalDose(
                start: dose.startDate,
                end: dose.endDate,
                rate: dose.unitsPerHour,
                temporary: dose.type == .tempBasal,
                automatic: dose.automatic ?? false,
                id: dose.syncIdentifier ?? UUID().uuidString)
        }

        basalDoses.append(contentsOf: insertedDoses)
        basalDoses.sort(by: { $0.start < $1.start })

        return basalDoses
    }

    func getBasalSchedule(interval: DateInterval) async throws -> [ScheduledBasal] {
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
        var items = [ScheduledBasal]()
        while date < interval.end {
            let scheduleActiveEnd: Date
            if idx+1 < schedules.endIndex {
                scheduleActiveEnd = schedules[idx+1].date
            } else {
                scheduleActiveEnd = interval.end
            }

            let schedule = schedules[idx].schedule

            let absoluteScheduleValues = schedule.truncatingBetween(start: date, end: scheduleActiveEnd)

            items.append(contentsOf: absoluteScheduleValues.map { ScheduledBasal(start: $0.startDate, end: $0.endDate, rate: $0.value) } )
            date = scheduleActiveEnd
            idx += 1
        }


        return items
    }

    func getBoluses(interval: DateInterval) async throws -> [Bolus] {
        return try await cache.doseStore.getBoluses(start: interval.start, end: interval.end).map { dose in
            Bolus(date: dose.startDate, amount: dose.deliveredUnits ?? dose.programmedUnits, automatic: dose.automatic ?? false, id: dose.syncIdentifier ?? UUID().uuidString)
        }
    }

    func getCarbEntries(interval: DateInterval) async throws -> [CarbEntry] {
        let entries = try await cache.carbStore.getCarbEntries(start: interval.start, end: interval.end)
        return entries.map { CarbEntry(date: $0.startDate, amount: $0.quantity) }
    }
}

extension Collection where Element == ScheduledBasal {
    func trim(start: Date, end: Date) -> [ScheduledBasal] {
        var selected = [ScheduledBasal]()
        for entry in self {
            if entry.start < end && entry.end > start {
                let clippedStart = Swift.max(entry.start, start)
                let clippedEnd = Swift.min(entry.end, end)
                selected.append(ScheduledBasal(start: clippedStart, end: clippedEnd, rate: entry.rate))
            }
        }
        return selected
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


