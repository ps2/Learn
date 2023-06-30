//
//  LoopLessons.swift
//  Learn
//
//  Created by Pete Schwamb on 6/30/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct LoopLessons: View {
    var body: some View {
        List {
            NavigationLink {
                MidAbsorptionISFChange()
                    .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
            } label: {
                Text("Mid-Absorption ISF Change")
            }
        }
    }
}

struct LoopLessons_Previews: PreviewProvider {
    static var previews: some View {
        LoopLessons()
    }
}
