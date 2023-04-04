//
//  DataSourcesSummaryView.swift
//  Learn
//
//  Created by Pete Schwamb on 2/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct DataSourcesSummaryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass


    @ObservedObject private var dataSourceManager = DataSourceManager()

    @State private var showingAvailableDataSources = false

    @State private var showingDataSourceSetup = false

    @State private var addingDataSource: DataSourceDescription?

    var basicChartsTimeInterval: TimeInterval {
        if horizontalSizeClass == .compact {
            return TimeInterval(hours: 6)
        } else {
            return TimeInterval(hours: 12)
        }
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Text("Learn").font(.system(size: 70))
                    .padding()
                List {
                    if dataSourceManager.dataSources.isEmpty {
                        VStack {
                            Text("Let's get started!")
                                .font(.title)
                                .padding(.bottom)
                        }.frame(minWidth: 0, maxWidth: .infinity)
                    } else {
                        ForEach(dataSourceManager.dataSources, id: \.dataSourceInstanceIdentifier) { source in
                            NavigationLink {
                                BasicChartsView(viewModel: BasicChartsViewModel(
                                    dataSource: source,
                                    displayUnits: .milligramsPerDeciliter,
                                    displayedTimeInterval: basicChartsTimeInterval
                                ))
                            } label: {
                                source.summaryView
                            }
                        }
                    }
                    Button(role: .none, action: {
                        showingAvailableDataSources = true
                    }) {
                        Label("New data source", systemImage: "plus.app")
                            .font(Font.system(.title2))
                            .padding(.vertical)
                    }
                    .confirmationDialog("Select a new Data Source", isPresented: $showingAvailableDataSources, titleVisibility: .visible) {
                        ForEach(dataSourceManager.dataSourceDescriptions) { dataSource in
                            Button(dataSource.localizedTitle) {
                                addingDataSource = dataSource
                            }
                        }
                    }
                }
                .sheet(item: $addingDataSource) { (dataSource) in
                    dataSourceManager.dataSourceTypeByIdentifier(identifier: dataSource.id)?.setupView(didSetupDataSource: { dataSource in
                        dataSourceManager.addDataSource(dataSource: dataSource)
                    })
                }
            }
        }
    }
}

struct DataSourcesView_Previews: PreviewProvider {
    static var previews: some View {
        DataSourcesSummaryView()
    }
}
