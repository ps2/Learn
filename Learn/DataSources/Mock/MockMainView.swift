//
//  MockMainView.swift
//  Learn
//
//  Created by Pete Schwamb on 6/7/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct MockMainView: View {
    var dataSource: MockDataSource

    var body: some View {
        BasicChartsView(dataSource: dataSource)
    }
}

struct MockMainView_Previews: PreviewProvider {
    static var previews: some View {
        MockMainView(dataSource: MockDataSource())
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}
