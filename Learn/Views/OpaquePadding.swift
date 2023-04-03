//
//  OpaquePadding.swift
//  Learn
//
//  Created by Pete Schwamb on 3/12/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI

struct OpaqueHorizontalPaddingModifier: ViewModifier {
    @State var amount: CGFloat

    func body(content: Content) -> some View {
        HStack {
            Spacer()
                .frame(minWidth: amount, maxWidth: amount, maxHeight: .infinity)
                .background(.background)
                .zIndex(20)
            content
            Spacer()
                .frame(minWidth: amount, maxWidth: amount, maxHeight: .infinity)
                .background(.background)
                .zIndex(20)
        }
    }
}

extension View {
    // Using this view modifier on a chart will make it detect long presses followed by panning, and
    // will convert the touch x location to a date, and report it as a preference with the key
    // ChartInspectionDatePreferenceKey
    func opaqueHorizontalPadding(amount: CGFloat = 8) -> some View {
        modifier(OpaqueHorizontalPaddingModifier(amount: amount))
    }
}
