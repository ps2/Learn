//
//  Cache.swift
//  Learn
//
//  Created by Pete Schwamb on 5/17/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit
import NightscoutKit
import os.log

protocol NightscoutDataCacheDelegate: AnyObject {
    func didUpdateCache(coverage: ClosedRange<Date>)
}

actor NightscoutDataCache {

    var glucoseStore: GlucoseStore
    var doseStore: DoseStore
    var carbStore: CarbStore
    var settingsStore: SettingsStore

    var nightscoutClient: NightscoutClient


    private var cacheCoverage: ClosedRange<Date>?

    func setDelegate(_ delegate: NightscoutDataCacheDelegate) {
        self.delegate = delegate
    }

    let cacheLength: TimeInterval = .days(365)

    weak var delegate: NightscoutDataCacheDelegate?

    private let log = OSLog(subsystem: "org.loopkit.Learn", category: "NightscoutDataManager")

    init(instanceIdentifier: String, nightscoutClient: NightscoutClient, cacheCoverage: ClosedRange<Date>?) {

        guard let directoryURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            fatalError("Could not access the document directory of the current process")
        }

        self.nightscoutClient = nightscoutClient
        self.cacheCoverage = cacheCoverage

        let storeURL = directoryURL.appendingPathComponent("nightscout_" + instanceIdentifier)
        print("Caching nightscout data in \(storeURL)")

        let cacheStore = PersistenceController(directoryURL: storeURL)

        let insulinModelProvider = PresetInsulinModelProvider(defaultRapidActingModel: nil)

        let provenance = Bundle.main.bundleIdentifier!


        glucoseStore = GlucoseStore(
            cacheStore: cacheStore,
            cacheLength: cacheLength,
            provenanceIdentifier: provenance)

        doseStore = DoseStore(
            cacheStore: cacheStore,
            cacheLength: cacheLength,
            insulinModelProvider: insulinModelProvider,
            longestEffectDuration: ExponentialInsulinModelPreset.rapidActingAdult.effectDuration,
            basalProfile: BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: 0, value: 1.5)]),
            insulinSensitivitySchedule: InsulinSensitivitySchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: 50)]),
            provenanceIdentifier: provenance)

        let defaultCarbAbsorptionTimes: CarbStore.DefaultAbsorptionTimes = (fast: .minutes(30), medium: .hours(3), slow: .hours(5))

        carbStore = CarbStore(
            healthKitSampleStore: nil,
            cacheStore: cacheStore,
            cacheLength: cacheLength,
            defaultAbsorptionTimes: defaultCarbAbsorptionTimes,
            provenanceIdentifier: provenance)

        settingsStore = SettingsStore(store: cacheStore, expireAfter: cacheLength)
    }

    // MARK: Remote fetching
    func syncGlucose(start: Date, end: Date) async throws {
        let interval = DateInterval(start: start, end: end)
        print("Fetching \(interval)")

        let samples: [NewGlucoseSample] = try await withCheckedThrowingContinuation { continuation in
            nightscoutClient.fetchGlucose(dateInterval: interval, maxCount: 5000) { result in
                switch result {
                case .failure(let error):
                    continuation.resume(throwing: error)
                case .success(let entries):
                    let samples = entries.compactMap { $0.newGlucoseSample }
                    continuation.resume(returning: samples)
                }
            }
        }
        glucoseStore.addGlucoseSamples(samples) { result in
            switch result {
            case .success(let storedSamples):
                print("added \(storedSamples.count) glucose samples")
            case .failure(let error):
                self.log.error("Unable to store glucose samples: %{public}@", error.localizedDescription)
            }
        }
    }

    func syncTreatments(start: Date, end: Date, updateExistingRecords: Bool) async throws {
        let interval = DateInterval(start: start.addingTimeInterval(-.hours(2)), end: end)
        print("Fetching \(interval) for treatments samples")

        let treatments: [NightscoutTreatment] = try await withCheckedThrowingContinuation { continuation in
            nightscoutClient.fetchTreatments(dateInterval: interval) { result in
                switch result {
                case .failure(let error):
                    continuation.resume(throwing: error)
                case .success(let entries):
                    print("Fetched \(entries.count) treatments")
                    continuation.resume(returning: entries)
                }
            }
        }

        var doses = [DoseEntry]()
        var carbs = [SyncCarbObject]()

        for treatment in treatments {
            switch treatment {
            case let tempBasal as TempBasalNightscoutTreatment:
                doses.append(DoseEntry(
                    type: .tempBasal,
                    startDate: tempBasal.timestamp,
                    endDate: tempBasal.timestamp.addingTimeInterval(tempBasal.duration),
                    value: tempBasal.rate,
                    unit: .unitsPerHour,
                    deliveredUnits: tempBasal.amount,
                    syncIdentifier: tempBasal.syncIdentifier
                ))
            case let bolus as BolusNightscoutTreatment:
                doses.append(DoseEntry(
                    type: .bolus,
                    startDate: bolus.timestamp,
                    endDate: bolus.timestamp.addingTimeInterval(bolus.duration),
                    value: bolus.programmed,
                    unit: .unitsPerHour,
                    deliveredUnits: bolus.amount,
                    syncIdentifier: bolus.syncIdentifier
                ))
            case let entry as CarbCorrectionNightscoutTreatment:
                carbs.append(SyncCarbObject(
                    absorptionTime: entry.absorptionTime,
                    createdByCurrentApp: false,
                    foodType: entry.notes,
                    grams: Double(entry.carbs),
                    startDate: entry.timestamp,
                    uuid: nil,
                    provenanceIdentifier: "nightscout",
                    syncIdentifier: entry.syncIdentifier,
                    syncVersion: nil,
                    userCreatedDate: entry.userEnteredAt,
                    userUpdatedDate: nil,
                    userDeletedDate: nil,
                    operation: .create,
                    addedDate: entry.userEnteredAt,
                    supercededDate: nil))
                break
            default:
                print("Converting \(self)")
                break
            }
        }

        try await doseStore.syncDoseEntries(doses, updateExistingRecords: updateExistingRecords)
        try await carbStore.setSyncCarbObjects(carbs)

        print("added \(doses.count) doses")
    }

    func syncSettings(start: Date, end: Date) async throws {
        let interval = DateInterval(start: start, end: end)

        let settings: [StoredSettings] = try await withCheckedThrowingContinuation({ continuation in
            nightscoutClient.fetchProfiles(dateInterval: interval) { result in
                switch result {
                case .failure(let error):
                    print("Failed to fetch settings: \(error)")
                    continuation.resume(throwing: error)
                case .success(let entries):
                    let samples = entries.compactMap { $0.storedSettings }
                    continuation.resume(returning: samples)
                }
            }
        })

        settingsStore.addStoredSettings(settings: settings) { error in
            if let error {
                self.log.error("Unable to save settings: %{public}@", error.localizedDescription)
            } else {
                print("Added \(settings.count) settings")
            }
        }
    }

    func syncRemoteData() async {
        let maxFetchInterval: TimeInterval = .days(7)

        let now = Date()
        let coverageStart = now.addingTimeInterval(-cacheLength)
        let fullCoverage: ClosedRange<Date> = coverageStart...now

        do {
            // First sync current data (last 6 hours)
            let refreshStart = now.addingTimeInterval(-.hours(6))
            try await syncData(startDate: refreshStart, endDate: now)
            cacheCoverage = min(cacheCoverage?.lowerBound ?? .distantFuture, refreshStart)...now
            delegate?.didUpdateCache(coverage: cacheCoverage!)

            // Now backfill missing data
            while(cacheCoverage != fullCoverage) {
                let queryEnd = cacheCoverage!.lowerBound
                let queryStart = max(queryEnd.addingTimeInterval(-maxFetchInterval), coverageStart)

                if queryStart < queryEnd {
                    try await syncData(startDate: queryStart, endDate: queryEnd, updateExistingRecords: false)
                }
                cacheCoverage = queryStart...cacheCoverage!.upperBound
                print("***** Coverage = \(String(describing: cacheCoverage))")
                delegate?.didUpdateCache(coverage: cacheCoverage!)
            }
        } catch {
            self.log.error("Error fetching data: %{public}@", error.localizedDescription)
        }
    }

    func syncData(startDate: Date, endDate: Date, updateExistingRecords: Bool = true) async throws {
        try await syncSettings(start: startDate, end: endDate)
        try await syncGlucose(start: startDate, end: endDate)
        try await syncTreatments(start: startDate, end: endDate, updateExistingRecords: updateExistingRecords)
    }

}
