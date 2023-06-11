//
//  NightscoutMainView.swift
//  Learn
//
//  Created by Pete Schwamb on 6/7/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct NightscoutMainView: View {
    var dataSource: NightscoutDataSource

    init(dataSource: NightscoutDataSource) {
        self.dataSource = dataSource
    }

    var body: some View {
        BasicChartsView(dataSource: dataSource)
    }
}

struct NightscoutMainView_Previews: PreviewProvider {
    static var previews: some View {
        NightscoutMainView(dataSource: NightscoutDataSource(name: "Nightscout Mock", url: URL(string: "https://test.com")!))
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
