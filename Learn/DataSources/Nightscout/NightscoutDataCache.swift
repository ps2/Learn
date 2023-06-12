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
    func didUpdateCache(cacheEndDate: Date)
}

actor NightscoutDataCache {

    var glucoseStore: GlucoseStore
    var doseStore: DoseStore
    var carbStore: CarbStore
    var settingsStore: SettingsStore

    var nightscoutClient: NightscoutClient


    private var cacheEndDate: Date?

    func setDelegate(_ delegate: NightscoutDataCacheDelegate) {
        self.delegate = delegate
    }

    let cacheLength: TimeInterval = .days(365)

    weak var delegate: NightscoutDataCacheDelegate?

    private let log = OSLog(subsystem: "org.loopkit.Learn", category: "NightscoutDataManager")

    init(instanceIdentifier: String, nightscoutClient: NightscoutClient, cacheEndDate: Date?) {

        guard let directoryURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            fatalError("Could not access the document directory of the current process")
        }

        self.nightscoutClient = nightscoutClient
        self.cacheEndDate = cacheEndDate

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

    // MARK: Local cache retrieval
    func getGlucoseSamples(start: Date, end: Date) async throws -> [StoredGlucoseSample] {
        let samples = try await glucoseStore.getGlucoseSamples(start: start, end: end)
        return samples
    }

    func getHistoricSettings(start: Date, end: Date) async throws -> [StoredSettings] {
        return []
    }

    func getInsulinDelivery(start: Date, end: Date) async throws -> [DoseEntry] {
        //return try await doseStore.getNormalizedDoseEntries(start: start, end: end)
        return []
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

    func syncTreatments(start: Date, end: Date) async throws {
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

        let doses = treatments.compactMap { $0.dose }

        try await doseStore.syncDoseEntries(doses)
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

        //cacheEndDate = nil

        var fetchedCurrentData = false

        do {
            while(!fetchedCurrentData) {
                let now = Date()
                let queryStart = max(cacheEndDate ?? .distantPast, now.addingTimeInterval(-cacheLength))
                let queryEnd = min(queryStart.addingTimeInterval(maxFetchInterval), now)

                try await syncData(startDate: queryStart, endDate: queryEnd)
                if queryEnd == now {
                    fetchedCurrentData = true
                }
                cacheEndDate = queryEnd
                delegate?.didUpdateCache(cacheEndDate: queryEnd)
            }
        } catch {
            self.log.error("Error fetching data: %{public}@", error.localizedDescription)
        }
    }

    func syncData(startDate: Date, endDate: Date) async throws {
        try await syncSettings(start: startDate, end: endDate)
        try await syncGlucose(start: startDate, end: endDate)
        try await syncTreatments(start: startDate, end: endDate)
    }

}
