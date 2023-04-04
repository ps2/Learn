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

        if let localFileURL, FileManager.default.fileExists(atPath: localFileURL.path) {
            Task {
                try await loadData()
            }
        }
    }

    func copyFile() async throws {

        guard let localFileURL else {
            throw IssueReportError.couldNotGetDocumentsDirectory
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard self.url.startAccessingSecurityScopedResource() else {
                        throw IssueReportError.permissionDenied
                    }

                    defer {
                        self.url.stopAccessingSecurityScopedResource()
                    }

                    let data = try Data(contentsOf: self.url)

                    print("Copying file to \(localFileURL)")

                    try data.write(to: localFileURL)

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func loadData() async throws {

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let localFileURL = self.localFileURL else {
                        throw IssueReportError.couldNotGetDocumentsDirectory
                    }

                    let data = try Data(contentsOf: localFileURL)
                    let reportStr = String(data: data, encoding: .utf8)!
                    let issueReport = try IssueReportParser().parse(reportStr)
                    print("Loaded data from \(localFileURL)")
                    DispatchQueue.main.async {
                        self.cachedGlucoseSamples = issueReport.cachedGlucoseSamples.map { $0.loopKitSample }
                        self.loadingState = .ready
                    }
                    continuation.resume()
                } catch {
                    self.loadingState = .failed(error)
                    continuation.resume(throwing: error)
                }
            }
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
                    try await dataSource.copyFile()
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

    var endOfData: Date? {
        return cachedGlucoseSamples.last?.startDate
    }

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
