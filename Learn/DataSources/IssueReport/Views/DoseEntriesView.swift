//
//  DoseEntriesView.swift
//  Learn
//
//  Created by Pete Schwamb on 6/15/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopIssueReportParser

struct DoseEntriesView: View {

    var doseEntries: [DoseEntry]

    var body: some View {
        List {
            ForEach(doseEntries, id: \.self) { entry in
                NavigationLink("\(entry.description)") {
                    Text("Not Implemented Yet")
                }
            }
        }
    }
}

struct DoseEntriesView_Previews: PreviewProvider {
    static var previews: some View {
        DoseEntriesView(doseEntries: [DoseEntry.mock])
    }
}

extension DoseEntry {
    var description: String {
        "\(startDate.formatted()) \(type) \(value)"
    }
}
