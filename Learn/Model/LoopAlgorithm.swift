//
//  LoopAlgorithm.swift
//  Learn
//
//  Created by Pete Schwamb on 6/30/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

actor LoopAlgorithm {
    var insulinActivityDuration = TimeInterval(hours: 6) + TimeInterval(minutes: 10)

    var dataSource: any DataSource

    init(dataSource: any DataSource) {
        self.dataSource = dataSource
    }

    func predictGlucose(at time: Date) async throws {
//        let deliveryHistoryInterval = DateInterval(start: time.addingTimeInterval(-insulinActivityDuration), end: time)
//        let doses = try await dataSource.getDoses(interval: deliveryHistoryInterval)
//        let basalSchedule = try await dataSource.getBasalHistory(interval: deliveryHistoryInterval)

        // Overlay basal schedule on basal doses
        

        // Compute insulin effects

        // Fetch carbs
        // Compute carb effects

        // Fetch glucose
        // Compute glucose momentum

        // Compute ICE
    }
}


