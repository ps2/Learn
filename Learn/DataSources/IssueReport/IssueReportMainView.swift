//
//  IssueReportMainView.swift
//  Learn
//
//  Created by Pete Schwamb on 6/7/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct IssueReportMainView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var dataSource: IssueReportDataSource

    var chartTimeInterval: TimeInterval {
        if horizontalSizeClass == .compact {
            return TimeInterval(hours: 6)
        } else {
            return TimeInterval(hours: 12)
        }
    }

    var body: some View {
        VStack {
            Text("Issue Report")
            BasicChartsView(
                viewModel: BasicChartsViewModel(displayedTimeInterval: chartTimeInterval),
                dataSource: dataSource)
        }
    }
}

struct IssueReportMainView_Previews: PreviewProvider {
    static var previews: some View {
        IssueReportMainView(dataSource: IssueReportDataSource.mock)
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
