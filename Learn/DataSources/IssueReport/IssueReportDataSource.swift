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

    @Published private var issueReport: IssueReport?

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

        Task {
            try await loadData()
        }
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
            return try IssueReportParser(skipDeviceLog: true).parse(reportStr)
        }.value
    }

    func loadData() async throws {

        guard let localFileURL = self.localFileURL else {
            throw IssueReportError.couldNotGetDocumentsDirectory
        }

        do {
            var targetFile: URL
            if FileManager.default.fileExists(atPath: localFileURL.path) {
                targetFile = localFileURL
            } else {
                targetFile = url
            }
            issueReport = try await Self.loadIssueReport(from: targetFile)
            if let issueReport {
                cachedGlucoseSamples = issueReport.cachedGlucoseSamples.map { $0.loopKitSample }
                print("cached samples count = \(cachedGlucoseSamples.count)")
            }
        } catch {
            log.error("Unable to load issue report: %{public}@", error.localizedDescription)
        }
    }

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
                Image(decorative: "loop")
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

    func getGlucoseValues(start: Date, end: Date) async throws -> [GlucoseValue] {
        let samples: [LoopKit.StoredGlucoseSample] = cachedGlucoseSamples.filter { $0.startDate >= start && $0.startDate <= end }
        return samples.map { GlucoseValue(quantity: $0.quantity, date: $0.startDate) }
    }

    func getTargetRanges(start: Date, end: Date) async throws -> [TargetRange] {
        return []
    }

    func getBasalDoses(start: Date, end: Date) async throws -> [Basal] {
        return []
    }

    func getBasalSchedule(start: Date, end: Date) async throws -> [ScheduledBasal] {
        return []
    }

    func getBoluses(start: Date, end: Date) async throws -> [Bolus] {
        return []
    }
}

extension LoopIssueReportParser.GlucoseCondition {
    var loopKitGlucoseCondition: LoopKit.GlucoseCondition {
        switch self {
        case .aboveRange:
            return .aboveRange
        case .belowRange:
            return .belowRange
        }
    }
}

extension LoopIssueReportParser.GlucoseTrend {
    var loopKitGlucoseTrend: LoopKit.GlucoseTrend {
        switch self {
        case .down:
            return .down
        case .upUpUp:
            return .upUpUp
        case .upUp:
            return .upUp
        case .up:
            return .up
        case .flat:
            return .flat
        case .downDown:
            return .downDown
        case .downDownDown:
            return .downDownDown
        }
    }
}

extension LoopIssueReportParser.StoredGlucoseSample {

    var loopKitSample: LoopKit.StoredGlucoseSample {
        return LoopKit.StoredGlucoseSample(
            uuid: uuid,
            provenanceIdentifier: provenanceIdentifier,
            syncIdentifier: syncIdentifier,
            syncVersion: syncVersion,
            startDate: startDate,
            quantity: quantity,
            condition: condition?.loopKitGlucoseCondition,
            trend: trend?.loopKitGlucoseTrend,
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
