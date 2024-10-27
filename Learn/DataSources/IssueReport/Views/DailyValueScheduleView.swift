//
//  DailyValueScheduleView.swift
//  Learn
//
//  Created by Pete Schwamb on 10/27/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import LoopKit

struct DailyValueScheduleView<T:RawRepresentable>: View {
    let name: String
    let schedule: DailyValueSchedule<T>

    let formatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()


    var body: some View {
        LabeledContent(name) {
            HStack {
                VStack {
                    ForEach(schedule.items, id: \.startTime) { (range) in
                        Text(formatter.string(from: range.startTime)!)
                    }
                }
                VStack {
                    ForEach(schedule.items, id: \.startTime) { (range) in
                        Text(String(describing: range.value))
                    }
                }
            }
        }
    }
}
