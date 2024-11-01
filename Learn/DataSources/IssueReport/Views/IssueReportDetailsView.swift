//
//  IssueReportDetailsView.swift
//  Learn
//
//  Created by Pete Schwamb on 6/15/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopIssueReportParser

struct IssueReportDetailsView: View {
    var issueReport: IssueReport

    var body: some View {
        List {
            LabeledContent("Created At", value: issueReport.generatedAt.formatted())
            NavigationLink("Build Details") {
                BuildDetailsView(buildDetails: issueReport.buildDetails)
            }
            NavigationLink("Device Logs") {
                DeviceLogsView(deviceLogs: issueReport.deviceLogs)
            }
            NavigationLink("Loop Settings") {
                LoopSettingsView(settings: issueReport.loopSettings)
            }
            NavigationLink("Forecast") {
                ForecastDetailsView(report: issueReport)
            }
            NavigationLink("Cached Glucose Samples") {
                Text("Not Implemented Yet")
            }
            NavigationLink("Cached Carb Entries") {
                Text("Not Implemented Yet")
            }
            NavigationLink("Cached Dose Entries") {
                DoseEntriesView(doseEntries: issueReport.cachedDoseEntries)
            }
        }
    }
}

struct IssueReportDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        IssueReportDetailsView(issueReport: IssueReport.mock)
    }
}
