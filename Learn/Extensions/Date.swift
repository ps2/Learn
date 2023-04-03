//
//  Date.swift
//  Learn
//
//  Created by Pete Schwamb on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation


extension Date {
    func roundDownToHour() -> Date? {
        var components = NSCalendar.current.dateComponents([.minute], from: self)
        let minute = components.minute ?? 0
        components.minute = -minute
        return Calendar.current.date(byAdding: components, to: self)
    }
}
