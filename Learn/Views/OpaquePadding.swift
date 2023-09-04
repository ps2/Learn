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
                .background(Color(UIColor.systemBackground))
                .zIndex(20)
            content
            Spacer()
                .frame(minWidth: amount, maxWidth: amount, maxHeight: .infinity)
                .background(Color(UIColor.systemBackground))
                .zIndex(20)
        }
    }
}

extension View {
    // Since chart clipping is problematic, we cover the left and right chart padding areas with opaque content.
    func opaqueHorizontalPadding(amount: CGFloat = 8) -> some View {
        modifier(OpaqueHorizontalPaddingModifier(amount: amount))
    }
}
