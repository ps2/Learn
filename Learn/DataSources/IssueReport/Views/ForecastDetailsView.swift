//
//  ForecastDetailsView.swift
//  Learn
//
//  Created by Pete Schwamb on 10/27/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopIssueReportParser

struct ForecastDetailsView: View {
    var report: IssueReport

    var body: some View {
        List {
            LabeledContent("Starting Glucose", value: String(describing: report.predictedGlucose.first!.quantity))
            LabeledContent("Eventual Glucose", value: String(describing: report.predictedGlucose.last!.quantity))
            LabeledContent("Insulin Effect", value: String(describing: report.insulinEffect.last!.quantity))
            LabeledContent("Carb Effect", value: String(describing: report.carbEffect.last?.quantity))
            LabeledContent("Insulin Counteraction Effects", value: String(describing: report.insulinCounteractionEffects.last!.quantity))
        }
        .navigationTitle("Forecast Details")
    }
}

struct ForecastDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        ForecastDetailsView(report: IssueReport.mock)
    }
}
