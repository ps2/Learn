//
//  TimeXAxis.swift
//  Learn
//
//  Created by Pete Schwamb on 7/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts


struct TimeXAxisModifier: ViewModifier {
    @State private var inspectionDate: Date?

    var labelOpacity: Double

    func body(content: Content) -> some View {
        content
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { value in
                if let date = value.as(Date.self) {
                    let hour = Calendar.current.component(.hour, from: date)
                    AxisValueLabel {
                        VStack(alignment: .leading) {
                            switch hour {
                            case 0, 12:
                                Text(date, format: .dateTime.hour())
                            default:
                                Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                            }
                            if value.index == 0 || hour == 0 {
                                Text(date, format: .dateTime.month().day())
                            }
                        }
                        .opacity(labelOpacity)
                    }

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

extension View {
    func timeXAxis(labelOpacity: Double = 1.0) -> some View {
        modifier(TimeXAxisModifier(labelOpacity: labelOpacity))
    }
}
