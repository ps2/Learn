//
//  ChartInspectionLookupModifier.swift
//  Learn
//
//  Created by Pete Schwamb on 1/16/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts

// This system allows a group of time series graphs to support coordinated inspection of points.
// The user can long press on one graph, and each graph can be notified of the inspection action
// along with the coordinate as the inspection date. From there, they can find the nearest chart
// value and display the inspection to the user.

// To set this up:
// 1. Each graph should install the chartLongPressInspection() view modifier on itself.
// 2. A parent view should watch for changes to the inspection date:
//    .onPreferenceChange(ChartInspectionDatePreferenceKey.self) { date in
//      viewModel.inspectionDate = date
//    }
// 3. The parent should set an environment value for the inspection date:
//    .environment(\.chartInspectionDate, viewModel.inspectionDate)
// 4. Children can use the inspection date environment value.
//    @Environment(\.chartInspectionDate) private var chartInspectionDate




private struct ChartInspectionDateKey: EnvironmentKey {
    static let defaultValue: Date? = nil
}

public extension EnvironmentValues {
    var chartInspectionDate: Date? {
        get { self[ChartInspectionDateKey.self] }
        set { self[ChartInspectionDateKey.self] = newValue }
    }
}

struct ChartInspectionAnchorPreferenceKey: PreferenceKey {
    typealias Value = Anchor<CGPoint>?

    static var defaultValue: Value = nil

    static func reduce(
        value: inout Value,
        nextValue: () -> Value
    ) {
        value = nextValue() ?? value
    }
}

struct ChartInspectionDatePreferenceKey: PreferenceKey {
    static var defaultValue: Date? = nil

    static func reduce(value: inout Date?, nextValue: () -> Date?) {
        if let n = nextValue() {
            value = n
        }
    }
}


struct ChartLongPressInspectionModifier: ViewModifier {
    @State private var inspectionDate: Date?

    func body(content: Content) -> some View {
        content
        .chartOverlay { proxy in
            GeometryReader { geo in
                // Ideally we could just be using a SwiftUI gesture here, but there is no facility
                // for reporting location for a long press. The only option in SwiftUI is to do a
                // long press followed by a drag gestures, but then you don't get location until the
                // user moves their finger, which hinders discoverability strongly.  The approach
                // here uses UIKit gesture detection to detect location on a long press, and continues
                // to report location on drag.
                InspectGestureView(minimumDuration: 0.2) { location in
                    inspectionDate = proxy.value(atX: location.x) as Date?
                } onEnded: {
                    inspectionDate = nil
                }
                .preference(key: ChartInspectionDatePreferenceKey.self, value: inspectionDate)
            }
        }
    }
}

extension View {
    // Using this view modifier on a chart will make it detect long presses followed by panning, and
    // will convert the touch x location to a date, and report it as a preference with the key
    // ChartInspectionDatePreferenceKey
    func chartLongPressInspection() -> some View {
        modifier(ChartLongPressInspectionModifier())
    }
}
