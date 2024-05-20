//
//  IssueReportDataSource.swift
//  Learn
//
//  Created by Pete Schwamb on 4/3/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import LoopKit
import LoopIssueReportParser
import os.log
import HealthKit
import LoopAlgorithm

enum IssueReportError: Error {
    case permissionDenied
    case couldNotGetDocumentsDirectory
}

final class IssueReportDataSource: DataSource, ObservableObject {
    static var localizedTitle = "Issue Report"

    static var dataSourceTypeIdentifier = "issuereportdatasource"

    private let log = OSLog(subsystem: "org.loopkit.Learn", category: "IssueReportDataSource")

    var dataSourceInstanceIdentifier: String
    var stateStorage: StateStorage?

    @Published public var issueReport: IssueReport?

    var cachedGlucoseSamples: [LoopKit.StoredGlucoseSample]

    var url: URL

    var name: String

    var localFileURL: URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent(dataSourceInstanceIdentifier + ".md")
    }

    init(url: URL, name: String, instanceIdentifier: String? = nil) {
        self.url = url
        self.name = name
        self.dataSourceInstanceIdentifier = instanceIdentifier ?? UUID().uuidString
        self.cachedGlucoseSamples = []
    }

    func importIssueReportFile() async throws {

        guard let localFileURL else {
            throw IssueReportError.couldNotGetDocumentsDirectory
        }

        guard self.url.startAccessingSecurityScopedResource() else {
            throw IssueReportError.permissionDenied
        }

        defer {
            self.url.stopAccessingSecurityScopedResource()
        }

        try await Self.copyFile(from: self.url, to: localFileURL)
    }

    static func copyFile(from source: URL, to dest: URL) async throws {
        Task {
            let data = try Data(contentsOf: source)

            try data.write(to: dest)
        }
    }

    static func loadIssueReport(from url: URL) async throws -> IssueReport {
        return try await Task {
            let data = try Data(contentsOf: url)
            let reportStr = String(data: data, encoding: .utf8)!
            return try IssueReportParser(skipDeviceLog: false).parse(reportStr)
        }.value
    }

    func loadData() async throws {

        guard let localFileURL = self.localFileURL else {
            throw IssueReportError.couldNotGetDocumentsDirectory
        }

        var targetFile: URL
        if FileManager.default.fileExists(atPath: localFileURL.path) {
            targetFile = localFileURL
        } else {
            targetFile = url
        }
        let report = try await Self.loadIssueReport(from: targetFile)
        Task { @MainActor in
            issueReport = report
            cachedGlucoseSamples = report.cachedGlucoseSamples.map { $0.loopKitSample }
        }
    }

    func syncData(interval: DateInterval) async { }

    convenience init?(rawState: RawStateValue) {
        guard let name = rawState["name"] as? String,
              let urlStr = rawState["url"] as? String,
              let url = URL(string: urlStr),
              let instanceIdentifier = rawState["instanceIdentifier"] as? String
        else
        {
            return nil
        }

        self.init(url: url, name: name, instanceIdentifier: instanceIdentifier)
    }

    var rawState: RawStateValue {
        let raw = [
            "name": name,
            "url": url.absoluteString,
            "instanceIdentifier": dataSourceInstanceIdentifier
        ]
        return raw
    }

    static func setupView(didSetupDataSource: @escaping (any DataSource) -> Void) -> AnyView {
        return AnyView(IssueReportSetupView(didFinishSetup: { (url, nickname) in
            let dataSource = IssueReportDataSource(
                url: url,
                name: nickname.isEmpty ? "Issue Report" : nickname)
            Task {
                do {
                    try await dataSource.importIssueReportFile()
                    try await dataSource.loadData()
                } catch {
                    print("error copying file: \(error)")
                }
            }
            didSetupDataSource(dataSource)
        }))
    }

    var summaryView: AnyView {
        AnyView(
            HStack {
                Image(decorative: "issue-report")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 40)
                Text(name)
            }
        )
    }

    var mainView: AnyView {
        AnyView(IssueReportMainView(dataSource: self))
    }

    var endOfData: Date? {
        return issueReport?.generatedAt
    }

    func getGlucoseValues(interval: DateInterval) async throws -> [StoredGlucoseSample] {
        cachedGlucoseSamples.filter { $0.startDate >= interval.start && $0.startDate <= interval.end }
    }

    func getTargetRangeHistory(interval: DateInterval) async throws -> [AbsoluteScheduleValue<ClosedRange<HKQuantity>>] {
        guard let report = issueReport,
              let schedule = report.loopSettings.glucoseTargetRangeSchedule else
        {
            return []
        }

        return schedule.truncatingBetween(start: interval.start, end: interval.end).map { entry in
            let min = HKQuantity(unit: schedule.unit, doubleValue: entry.value.minValue)
            let max = HKQuantity(unit: schedule.unit, doubleValue: entry.value.maxValue)
            return AbsoluteScheduleValue(startDate: entry.startDate, endDate: entry.endDate, value: ClosedRange(uncheckedBounds: (lower: min, upper: max)))
        }
    }

    func getInsulinSensitivityHistory(interval: DateInterval) async throws -> [AbsoluteScheduleValue<HKQuantity>] {
        guard let report = issueReport, let isf = report.loopSettings.insulinSensitivitySchedule else
        {
            return []
        }
        return isf.quantitiesBetween(start: interval.start, end: interval.end)
    }

    func getBasalHistory(interval: DateInterval) async throws -> [AbsoluteScheduleValue<Double>] {
        guard let report = issueReport, let basal = report.loopSettings.basalRateSchedule else
        {
            return []
        }
        return basal.between(start: interval.start, end: interval.end)
    }

    func getCarbRatioHistory(interval: DateInterval) async throws -> [AbsoluteScheduleValue<Double>] {
        guard let report = issueReport, let carbRatio = report.loopSettings.carbRatioSchedule else
        {
            return []
        }
        return carbRatio.between(start: interval.start, end: interval.end)
    }

    func getDoses(interval: DateInterval) async throws -> [DoseEntry] {
        guard let report = issueReport else
        {
            return []
        }
        let doses = report.normalizedDoseEntries.filterDateInterval(interval: interval)
        return doses.filter { $0.deliveryType == .bolus || $0.duration > 0 }
    }

    func getCarbEntries(interval: DateInterval) async throws -> [StoredCarbEntry] {
        guard let report = issueReport else
        {
            return []
        }
        return report.cachedCarbEntries.filterDateInterval(interval: interval)
    }

    func getDosingLimits(at date: Date) async throws -> DosingLimits {
        return DosingLimits(
            suspendThreshold: issueReport?.loopSettings.suspendThreshold,
            maxBolus: issueReport?.loopSettings.maximumBolus,
            maxBasalRate: issueReport?.loopSettings.maximumBasalRatePerHour)
    }
}

extension StoredGlucoseSample {

    var loopKitSample: LoopKit.StoredGlucoseSample {
        return LoopKit.StoredGlucoseSample(
            uuid: uuid,
            provenanceIdentifier: provenanceIdentifier,
            syncIdentifier: syncIdentifier,
            syncVersion: syncVersion,
            startDate: startDate,
            quantity: quantity,
            condition: condition,
            trend: trend,
            trendRate: trendRate,
            isDisplayOnly: isDisplayOnly,
            wasUserEntered: wasUserEntered,
            device: nil,
            healthKitEligibleDate: healthKitEligibleDate)
    }
}


extension IssueReportDataSource {
    static var mock: IssueReportDataSource {
        let issueReport = Bundle.main.url(forResource: "Example-Issue-Report", withExtension: "md")!
        return IssueReportDataSource(url: issueReport, name: "Example Issue Report")
    }
}

extension IssueReport {
    static var mock: IssueReport {
        let issueReportURL = Bundle.main.url(forResource: "Example-Issue-Report", withExtension: "md")!
        let data = try! Data(contentsOf: issueReportURL)
        let reportStr = String(data: data, encoding: .utf8)!
        return try! IssueReportParser(skipDeviceLog: false).parse(reportStr)

    }
}
