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
            } label: {
                Text("Mid-Absorption ISF Change")
            }
            NavigationLink {
                LoopChartsView(dataSource: dataSource)
            } label: {
                Text("Algo Effects from Mock Data Source")
            }
            NavigationLink {
                LoopDosingExample()
            } label: {
                Text("Loop Dosing Example")
            }
            NavigationLink {
                RetrospectiveCorrectionExample()
            } label: {
                Text("Retrospective Correction")
            }
            NavigationLink {
                InsulinDeliveryExample()
            } label: {
                Text("Insulin Delivery")
            }
            NavigationLink {
                AlgorithmDetailsViewExample()
            } label: {
                Text("Forecast Review")
            }
        }
        .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}

struct LoopLessons_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoopLessons()
        }
    }
}
