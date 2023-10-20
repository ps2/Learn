//
//  DataSourcesSummaryView.swift
//  Learn
//
//  Created by Pete Schwamb on 2/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct DataSourcesSummaryView: View {
    @ObservedObject private var dataSourceManager = DataSourceManager()

    @State private var showingAvailableDataSources = false

    @State private var showingDataSourceSetup = false

    @State private var addingDataSource: DataSourceDescription?

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
                                .foregroundColor(.green)
                        }
                    } else {
                        ForEach(dataSourceManager.dataSources, id: \.dataSourceInstanceIdentifier) { source in
                            NavigationLink {
                                source.mainView
                            } label: {
                                source.summaryView
                            }
                            .contextMenu {
                                Button(action: {
                                    dataSourceManager.removeDataSource(dataSource: source)
                                }){
                                    Text("Delete")
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    NavigationLink {
                        LoopLessons()
                    } label: {
                        Text("Loop Lessons")
                    }
                    NavigationLink {
                        List {
                            NavigationLink {
                                GlucoseDistribution(dataSource: MockDataSource(), interval: .lastWeek)
                            } label: {
                                Text("Glucose Distribution")
                            }
                        }
                    } label: {
                        Text("Data Review")
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
                .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
                .sheet(item: $addingDataSource) { (dataSource) in
                    dataSourceManager.dataSourceTypeByIdentifier(identifier: dataSource.id)?.setupView(didSetupDataSource: { dataSource in
                        dataSourceManager.addDataSource(dataSource: dataSource)
                    })
                }
            }
        }
    }

    func delete(at offsets: IndexSet) {
        let sources = offsets.map { dataSourceManager.dataSources[$0] }
        for source in sources {
            dataSourceManager.removeDataSource(dataSource: source)
        }
    }
}

struct DataSourcesView_Previews: PreviewProvider {
    static var previews: some View {
        DataSourcesSummaryView()
    }
}
