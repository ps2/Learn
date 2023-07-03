//
//  LoopAlgorithm.swift
//  Learn
//
//  Created by Pete Schwamb on 6/30/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

struct AlgorithmEffectSummary {
    let date: Date

    // All in terms of net glucose effects in mg/dL
    let insulin: Double
    let carb: Double
    let momentum: Double
    let ice: Double
    let rc: Double
}

actor LoopAlgorithm {

    var dataSource: any DataSource

    let insulinModelProvider = PresetInsulinModelProvider(defaultRapidActingModel: nil)
    var insulinActivityDuration = TimeInterval(hours: 6) + TimeInterval(minutes: 10)

    init(dataSource: any DataSource) {
        self.dataSource = dataSource
    }

    func predictGlucose(at time: Date) async throws {
        let deliveryHistoryInterval = DateInterval(start: time.addingTimeInterval(-insulinActivityDuration), end: time)
        let forecastInterval = DateInterval(start: time, end: time.addingTimeInterval(insulinActivityDuration))
        let doses = try await dataSource.getDoses(interval: deliveryHistoryInterval)
        let basalHistory = try await dataSource.getBasalHistory(interval: deliveryHistoryInterval)

        let sensitivityInterval = DateInterval(start: deliveryHistoryInterval.start, end: forecastInterval.end)
        let sensitivityHistory = try await dataSource.getInsulinSensitivityHistory(interval: sensitivityInterval)

        // Overlay basal history on basal doses, splitting doses to get amount delivered relative to basal
        let annotatedDoses = doses.annotated(with: basalHistory)

        let glucoseEffects = annotatedDoses.glucoseEffects(insulinModelProvider: insulinModelProvider, longestEffectDuration: insulinActivityDuration, insulinSensitivityHistory: sensitivityHistory)



        // Compute insulin effects

        // Fetch carbs
        // Compute carb effects

        // Fetch glucose
        // Compute glucose momentum

        // Compute ICE
    }
}


