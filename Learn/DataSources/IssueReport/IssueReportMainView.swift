//
//  IssueReportMainView.swift
//  Learn
//
//  Created by Pete Schwamb on 6/7/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct IssueReportMainView: View {
    var dataSource: IssueReportDataSource

    var body: some View {
        VStack {
            Text("Issue Report")
            BasicChartsView(dataSource: dataSource)
        }
    }
}

struct IssueReportMainView_Previews: PreviewProvider {
    static var previews: some View {
        IssueReportMainView(dataSource: IssueReportDataSource.mock)
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
