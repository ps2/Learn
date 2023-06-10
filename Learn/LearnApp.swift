//
//  LearnApp.swift
//  Learn
//
//  Created by Pete Schwamb on 9/16/22.
//

import SwiftUI

@main
struct LearnApp: App {
    let formatters = QuantityFormatters(glucoseUnit: .milligramsPerDeciliter)

    var body: some Scene {
        WindowGroup {
            DataSourcesSummaryView()
                .environmentObject(formatters)
        }
    }
}
