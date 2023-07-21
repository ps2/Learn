//
//  InsulinDeliveryExample.swift
//  Learn
//
//  Created by Pete Schwamb on 7/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct InsulinDeliveryExample: View {
    var body: some View {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-18 * 3600)

        let mockDataSource = MockDataSource()
        let interval = DateInterval(start: startDate, end: endDate)

        let doses = mockDataSource.getMockDoses(interval: interval)
        let basalHistory = mockDataSource.getMockBasalHistory(start: interval.start, end: interval.end)

        return InsulinDosesChart(startTime: startDate, endTime: endDate, doses: doses, basalHistory: basalHistory, chartUnitOffset: .constant(0), numSegments: 6)
            .opaqueHorizontalPadding()
    }
}

struct InsulinDeliveryExample_Previews: PreviewProvider {
    static var previews: some View {
        InsulinDeliveryExample()
    }
}
