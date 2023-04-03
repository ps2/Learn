//
//  BasalSchedule.swift
//  ScrollableCharts
//
//  Created by Pete Schwamb on 1/16/23.
//

import Foundation

class BasalSchedule {

    private var values: [InsulinValue]

    init() {

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions =  [.withInternetDateTime, .withFractionalSeconds]

        // {
        //    "_id":"63bd9246d7b5c982c60a5ae0",
        //    "sgv":171,
        //    "date":1673368117000,
        //    "dateString":"2023-01-10T16:28:37.000Z",
        //    "trend":3,
        //    "direction":"FortyFiveUp",
        //    "device":"share2",
        //    "type":"sgv",
        //    "utcOffset":0,
        //    "sysTime":"2023-01-10T16:28:37.000Z",
        //    "mills":1673368117000
        // }

        let path = Bundle.main.path(forResource: "historical_glucose", ofType: "json")!
        let fixtures = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)), options: []) as! [[String: Any]]

        values = fixtures.map { entry in
            let date = formatter.date(from: entry["dateString"] as! String)!
            return InsulinValue(value: entry["sgv"] as! Double, date: date)
        }
    }

    func fetchData(startDate: Date, endDate: Date) -> [InsulinValue] {
        let rval = values.filter { value in
            value.date > startDate && value.date < endDate
        }
        return rval
    }
}
