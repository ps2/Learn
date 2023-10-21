//
//  TimeIntervalXAxisModifier.swift
//  Learn
//
//  Created by Pete Schwamb on 10/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts


struct TimeIntervalXAxisModifier: ViewModifier {
    let values: AxisMarkValues

    let formatter: DateComponentsFormatter

    init(values: AxisMarkValues, unitsStyle: DateComponentsFormatter.UnitsStyle = .abbreviated, allowedUnits: NSCalendar.Unit = [.hour]) {
        self.values = values
        formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = allowedUnits
        formatter.unitsStyle = unitsStyle
    }

    func body(content: Content) -> some View {
        content
        .chartXAxis {
            AxisMarks { (value) in
                AxisValueLabel {
                    if let interval: TimeInterval = value.as(TimeInterval.self) {
                        Text(formatter.string(from: interval)!)
                    }
                }
            }
        }
    }
}

extension View {
    func timeIntervalXAxis(values: AxisMarkValues = .automatic, unitsStyle: DateComponentsFormatter.UnitsStyle = .abbreviated, allowedUnits: NSCalendar.Unit = [.hour]) -> some View {
        modifier(TimeIntervalXAxisModifier(values: values, unitsStyle: unitsStyle, allowedUnits: allowedUnits))
    }
}
