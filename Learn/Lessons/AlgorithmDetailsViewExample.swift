//
//  AlgorithmDetailsViewExample.swift
//  Learn
//
//  Created by Pete Schwamb on 7/24/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct AlgorithmDetailsViewExample: View {
    var body: some View {
        AlgorithmDetailsView(dataSource: MockDataSource())
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}

struct ForecastReviewExample_Previews: PreviewProvider {
    static var previews: some View {
        AlgorithmDetailsViewExample()
    }
}
