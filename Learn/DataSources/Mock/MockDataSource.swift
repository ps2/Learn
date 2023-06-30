//
//  MockDataSource.swift
//  Learn
//
//  Created by Pete Schwamb on 2/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import LoopKit
import HealthKit

class MockDataSource: DataSource {
    @Published var loadingState: LoadingState = .isLoading

    var stateStorage: StateStorage?

    var endOfData: Date? {
        return nil
    }

    func getMockGlucoseValues(start: Date, end: Date) -> [GlucoseValue] {
        stride(from: start, through: end, by: TimeInterval(5 * 60)).map { date in
            let value = 110.0 + sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 5) / (3600*5) * Double.pi * 2) * 60
            let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value)
            return GlucoseValue(quantity: quantity, date: date)
        }
    }

    func getGlucoseValues(interval: DateInterval) async throws -> [GlucoseValue] {
        return getMockGlucoseValues(start: interval.start, end: interval.end)
    }

    func getMockTargetRanges(start: Date, end: Date) -> [TargetRange] {
        let targetTimeInterval = TimeInterval(90 * 60)

        let intervalStart: Date = start - start.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: targetTimeInterval)

        return stride(from: intervalStart, through: end, by: targetTimeInterval).map { date in
            let value = 110.0 + sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 2) / (3600*3) * Double.pi * 2) * 10

            let min = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value-5)
            let max = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value+5)

            return TargetRange(min: min, max: max, startTime: date, endTime: date.addingTimeInterval(targetTimeInterval))
        }
    }

    func getTargetRanges(interval: DateInterval) async throws -> [TargetRange] {
        return getMockTargetRanges(start: interval.start, end: interval.end)
    }

    func getMockBasalDoses(start: Date, end: Date) -> [BasalDose] {
        let spaceBetweenChanges = TimeInterval(10 * 60)

        let intervalStart: Date = start - start.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: spaceBetweenChanges)

        return stride(from: intervalStart, through: end, by: spaceBetweenChanges).map { date in
            let value = sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 5) / (3600*5) * Double.pi * 2) + 1.1
            return BasalDose(start: date, end: date.addingTimeInterval(spaceBetweenChanges), rate: value, temporary: false, automatic: false, id: UUID().uuidString)
        }
    }

    func getBasalDoses(interval: DateInterval) async throws -> [BasalDose] {
        return getMockBasalDoses(start: interval.start, end: interval.end)
    }

    func getMockBasalSchedule(start: Date, end: Date) -> [ScheduledBasal] {
        let spaceBetweenChanges = TimeInterval(3 * 3600)

        let intervalStart: Date = start - start.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: spaceBetweenChanges)

        return stride(from: intervalStart, through: end, by: spaceBetweenChanges).map { date in
            let value = sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 3) / (3600*3) * Double.pi * 1.5) + 1
            return ScheduledBasal(start: date, end: date.addingTimeInterval(spaceBetweenChanges), rate: value)
        }
    }

    func getCarbEntries(interval: DateInterval) async throws -> [CarbEntry] {
        return getMockCarbEntries(start: interval.start, end: interval.end)
    }

    func getMockCarbEntries(start: Date, end: Date) -> [CarbEntry] {
        let spaceBetweenEntries = TimeInterval(2.2 * 3600)

        let intervalStart: Date = start - start.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: spaceBetweenEntries)

        return stride(from: intervalStart, through: end, by: spaceBetweenEntries).map { date in
            let value = sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 3) / (3600*3) * Double.pi * 80) + 10
            return CarbEntry(date: date, amount: HKQuantity(unit: .gram(), doubleValue: value))
        }
    }


    func getBasalSchedule(interval: DateInterval) async throws -> [ScheduledBasal] {
        return getMockBasalSchedule(start: interval.start, end: interval.end)
    }

    func getMockBoluses(start: Date, end: Date) -> [Bolus] {
        let spaceBetweenBoluses = TimeInterval(2.2 * 3600)

        let intervalStart: Date = start - start.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: spaceBetweenBoluses)

        return stride(from: intervalStart, through: end, by: spaceBetweenBoluses).map { date in
            let value = sin(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600 * 3) / (3600*3) * Double.pi * 2) + 1
            return Bolus(date: date, amount: value, automatic: false, id: UUID().uuidString)
        }
    }

    func getBoluses(interval: DateInterval) async throws -> [Bolus] {
        return getMockBoluses(start: interval.start, end: interval.end)
    }
    
    func syncData(interval: DateInterval) async { }


    static var localizedTitle: String = "MockDataSource"
    static var dataSourceTypeIdentifier: String = "mockdatasource"

    typealias RawStateValue = [String: Any]

    var name: String = "Example Data Source"

    static func setupView(didSetupDataSource: @escaping (any DataSource) -> Void) -> AnyView {
        AnyView(Text("Hello"))
    }

    var summaryView: AnyView {
        return AnyView(Text("Mock Data"))
    }

    var mainView: AnyView {
        AnyView(MockMainView(dataSource: self))
    }

    var dataSourceInstanceIdentifier: String

    init() {
        dataSourceInstanceIdentifier = UUID().uuidString
    }

    required init?(rawState: RawStateValue) {
        guard let name = rawState["name"] as? String,
              let instanceIdentifier = rawState["instanceIdentifier"] as? String else
        {
            return nil
        }

        self.name = name
        self.dataSourceInstanceIdentifier = instanceIdentifier
    }

    var rawState: RawStateValue {
        return [
            "name": name,
            "instance": dataSourceInstanceIdentifier
        ]
    }

}
