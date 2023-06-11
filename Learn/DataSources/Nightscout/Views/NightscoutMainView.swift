//
//  NightscoutMainView.swift
//  Learn
//
//  Created by Pete Schwamb on 6/7/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct NightscoutMainView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var dataSource: NightscoutDataSource

    var chartTimeInterval: TimeInterval {
        if horizontalSizeClass == .compact {
            return TimeInterval(hours: 6)
        } else {
            return TimeInterval(hours: 12)
        }
    }

    init(dataSource: NightscoutDataSource) {
        self.dataSource = dataSource
    }

    var body: some View {
        BasicChartsView(
            viewModel: BasicChartsViewModel(displayedTimeInterval: chartTimeInterval),
            dataSource: dataSource)
    }
}

struct NightscoutMainView_Previews: PreviewProvider {
    static var previews: some View {
        NightscoutMainView(dataSource: NightscoutDataSource(name: "Nightscout Mock", url: URL(string: "https://test.com")!))
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
