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
        ScrollView {
            Text(dataSource.name)
            LoopChartsView(dataSource: dataSource)
                .refreshable {
                    await dataSource.syncRemoteData()
                }
            Divider()
                .padding(.vertical)
        }
    }
}

struct NightscoutMainView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NightscoutMainView(dataSource: NightscoutDataSource(name: "Nightscout Mock", url: URL(string: "https://test.com")!))
                .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
        }
    }
}
