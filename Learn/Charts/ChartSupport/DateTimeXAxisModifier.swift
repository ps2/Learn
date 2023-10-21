//
//  DateTimeXAxisModifier.swift
//  Learn
//
//  Created by Pete Schwamb on 7/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts


struct DateTimeXAxisModifier: ViewModifier {
    @State private var inspectionDate: Date?

    var values: AxisMarkValues
    var labelOpacity: Double

    func body(content: Content) -> some View {
        content
        .chartXAxis {
            AxisMarks(values: values) { value in
                if let date = value.as(Date.self) {
                    let hour = Calendar.current.component(.hour, from: date)
                    AxisValueLabel {
                        Text(date, format: .dateTime.hour())
                            .opacity(labelOpacity)
                    }

                    if labelOpacity != 0 {
                        if hour == 0 {
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        } else {
                            AxisGridLine()
                            AxisTick()
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func dateTimeXAxis(values: AxisMarkValues = .automatic, labelOpacity: Double = 1.0) -> some View {
        modifier(DateTimeXAxisModifier(values: values, labelOpacity: labelOpacity))
    }
}
