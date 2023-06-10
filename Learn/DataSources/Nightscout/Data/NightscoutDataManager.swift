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

protocol NightscoutDataManagerDelegate: AnyObject {
    func didUpdateCache(cacheEndDate: Date)
}

actor NightscoutDataManager {

    private var glucoseStore: GlucoseStore
    private var doseStore: DoseStore
    private var carbStore: CarbStore
    private var nightscoutClient: NightscoutClient

    private var cacheEndDate: Date?

    func setDelegate(_ delegate: NightscoutDataManagerDelegate) {
        self.delegate = delegate
    }

    let cacheLength: TimeInterval = .days(365)

    weak var delegate: NightscoutDataManagerDelegate?

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
    }

    // MARK: Local cache retrieval
    func getGlucoseSamples(start: Date, end: Date) async throws -> [StoredGlucoseSample] {
        return try await glucoseStore.getGlucoseSamples(start: start, end: end)
    }

    func getHistoricSettings(start: Date, end: Date) async throws -> [StoredSettings] {
        return []
    }

    func getInsulinDelivery(start: Date, end: Date) async throws -> [DoseEntry] {
        //return try await doseStore.getNormalizedDoseEntries(start: start, end: end)
        return []
    }



    // MARK: Remote fetching
    func fetchGlucoseSamples(start: Date, end: Date) async throws -> [NewGlucoseSample] {
        let interval = DateInterval(start: start, end: end)
        print("Fetching \(interval)")

        return try await withCheckedThrowingContinuation { continuation in
            nightscoutClient.fetchGlucose(dateInterval: interval, maxCount: 1000) { result in
                switch result {
                case .failure(let error):
                    continuation.resume(throwing: error)
                case .success(let entries):
                    let samples = entries.compactMap { $0.newGlucoseSample }
                    continuation.resume(returning: samples)
                }
            }
        }
    }

    func fetchHistoricSettings(start: Date, end: Date, completion: @escaping (Result<[StoredSettings], Error>) -> Void) {
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

    func syncRemoteData() async {
        let maxFetchInterval: TimeInterval = .days(7)

        var fetchedCurrentData = false

        do {
            while(!fetchedCurrentData) {
                let now = Date()
                let queryStart = max(cacheEndDate ?? .distantPast, now.addingTimeInterval(-cacheLength))
                let queryEnd = min(queryStart.addingTimeInterval(maxFetchInterval), now)

                try await fetchAndStoreData(startDate: queryStart, endDate: queryEnd)
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

    func fetchAndStoreData(startDate: Date, endDate: Date) async throws {
        let samples = try await fetchGlucoseSamples(start: startDate, end: endDate)
        glucoseStore.addGlucoseSamples(samples) { result in
            print("added \(samples.count)")
        }

    }

}
