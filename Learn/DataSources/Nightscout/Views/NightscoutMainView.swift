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
            VStack(spacing: 20) {
                Text(dataSource.name)
                LoopChartsView(dataSource: dataSource)
                    .refreshable {
                        await dataSource.syncRemoteData()
                    }
                NavigationLink {
                    GlucoseDistribution(dataSource: dataSource, interval: .lastMonth)
                        .frame(maxHeight: 200)
                        .padding()
                } label: {
                    Text("Glucose Distribution")
                }
                NavigationLink {
                    GlucoseLagPlot(dataSource: dataSource, interval: .lastTwoWeeks)
                        .frame(maxHeight: 500)
                        .padding()
                } label: {
                    Text("Glucose Lag Plot")
                }
                NavigationLink {
                    AutocorrelationPlot(dataSource: dataSource, interval: .lastTwoWeeks)
                        .frame(maxHeight: 500)
                        .padding()
                } label: {
                    Text("Autocorrelation Plot")
                }
            }
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
