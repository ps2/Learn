//
//  IssueReportMainView.swift
//  Learn
//
//  Created by Pete Schwamb on 6/7/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct IssueReportMainView: View {
    @ObservedObject var dataSource: IssueReportDataSource

    @State private var error: Error?

    var issueReportDate: String {
        if let report = dataSource.issueReport {
            return report.generatedAt.formatted()
        } else {
            return ""
        }
    }

    var body: some View {
        ScrollView {
            if let error = error {
                Text(String(describing: error))
            }
            else if let issueReport = dataSource.issueReport {
                Text(dataSource.name)
                NavigationLink("Details") {
                    IssueReportDetailsView(issueReport: issueReport)
                }
                BasicChartsView(dataSource: dataSource)
                Divider()
                    .padding(.vertical)
                NavigationLink("Forecast Review") {
                    ForecastReview(dataSource: dataSource)
                }
            }
        }
        .task {
            do {
                try await dataSource.loadData()
            } catch {
                self.error = error
            }
        }
    }
}

struct IssueReportMainView_Previews: PreviewProvider {
    static var dataSource = IssueReportDataSource.mock

    static var previews: some View {
        IssueReportMainView(dataSource: dataSource)
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
