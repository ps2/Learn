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

    var body: some View {
        VStack {
            Text("Issue Report")
            BasicChartsView(dataSource: dataSource)
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
