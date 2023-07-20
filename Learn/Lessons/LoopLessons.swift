//
//  LoopLessons.swift
//  Learn
//
//  Created by Pete Schwamb on 6/30/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct LoopLessons: View {
    var dataSource = MockDataSource()

    var body: some View {
        List {
            NavigationLink {
                MidAbsorptionISFChange()
                    .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
            } label: {
                Text("Mid-Absorption ISF Change")
            }
            NavigationLink {
                BasicChartsView(dataSource: dataSource)
                    .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
            } label: {
                Text("Algo Effects from Mock Data Source")
            }
            NavigationLink {
                LoopDosingExample()
                    .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
            } label: {
                Text("Loop Dosing Example")
            }
            NavigationLink {
                RetrospectiveCorrectionExample()
                    .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
            } label: {
                Text("Retrospective Correction")
            }
        }
    }
}

struct LoopLessons_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoopLessons()
        }
    }
}
