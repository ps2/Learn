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
        BasicChartsView(viewModel: BasicChartsViewModel(
            dataSource: dataSource,
            displayUnits: .milligramsPerDeciliter,
            displayedTimeInterval: chartTimeInterval
        ))
    }
}

struct IssueReportMainView_Previews: PreviewProvider {
    static var previews: some View {
        IssueReportMainView(dataSource: IssueReportDataSource(url: URL(string: "file://mock")!, name: "Mock Issue Report"))
    }
}
