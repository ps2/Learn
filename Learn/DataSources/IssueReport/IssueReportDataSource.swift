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

enum IssueReportError: Error {
    case permissionDenied
    case couldNotGetDocumentsDirectory
}

final class IssueReportDataSource: DataSource {
    static var localizedTitle = "Issue Report"

    static var dataSourceTypeIdentifier = "issuereportdatasource"

    var dataSourceInstanceIdentifier: String

    @Published var loadingState: LoadingState = .isLoading
    var loadingStatePublisher: Published<LoadingState>.Publisher { $loadingState }

    @MainActor
    var cachedGlucoseSamples: [LoopKit.StoredGlucoseSample]

    @MainActor
    var url: URL

    @MainActor
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

        if let localFileURL, FileManager.default.fileExists(atPath: localFileURL.path) {
            Task {
                try await loadData()
            }
        }
    }

    @MainActor
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

            print("Copying \(source) to \(dest)")

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

    @MainActor
    func loadData() async throws {
        print("Loading data at \(Date())")

        guard let localFileURL = self.localFileURL else {
            throw IssueReportError.couldNotGetDocumentsDirectory
        }

        do {
            let issueReport = try await Self.loadIssueReport(from: localFileURL)
            print("Loaded data from \(localFileURL)")
            self.cachedGlucoseSamples = issueReport.cachedGlucoseSamples.map { $0.loopKitSample }
            self.loadingState = .ready
        } catch {
            self.loadingState = .failed(error)
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

    @MainActor
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

    @MainActor
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

    @MainActor
    var endOfData: Date? {
        return cachedGlucoseSamples.last?.startDate
    }

    @MainActor
    func getGlucoseSamples(start: Date, end: Date, completion: @escaping (Result<[LoopKit.StoredGlucoseSample], Error>) -> Void) {
        let matching = cachedGlucoseSamples.filter { $0.startDate >= start && $0.startDate <= end }
        completion(.success(matching))
    }

    func getHistoricSettings(start: Date, end: Date, completion: @escaping (Result<[LoopKit.StoredSettings], Error>) -> Void) {
        //.completion(.success([]))
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
