//
//  ForecastReviewExample.swift
//  Learn
//
//  Created by Pete Schwamb on 7/24/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct ForecastReviewExample: View {
    var body: some View {
        ForecastReview(dataSource: MockDataSource())
            .environmentObject(QuantityFormatters(glucoseUnit: .milligramsPerDeciliter))
    }
}

struct ForecastReviewExample_Previews: PreviewProvider {
    static var previews: some View {
        ForecastReviewExample()
    }
}
