//
//  MockMainView.swift
//  Learn
//
//  Created by Pete Schwamb on 6/7/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct MockMainView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var dataSource: MockDataSource

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
            displayedTimeInterval: chartTimeInterval
        ), dataSource: dataSource)
    }
}

struct MockMainView_Previews: PreviewProvider {
    static var previews: some View {
        MockMainView(dataSource: MockDataSource())
    }
}
