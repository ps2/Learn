//
//  DeviceLogsView.swift
//  Learn
//
//  Created by Pete Schwamb on 6/15/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopIssueReportParser

struct DeviceLogsView: View {
    var deviceLogs: [DeviceCommunicationLogEntry]

    var body: some View {
        List {
            ForEach(deviceLogs, id: \.self) { entry in
                NavigationLink("\(String(describing: entry))") {
                    Text("Not Implemented Yet")
                }
            }
        }
    }
}

struct DeviceLogsView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceLogsView(deviceLogs: [])
    }
}
