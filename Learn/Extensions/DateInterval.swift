//
//  DateInterval.swift
//  Learn
//
//  Created by Pete Schwamb on 10/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

extension DateInterval {
    static var lastWeek: DateInterval {
        let now = Date()
        return DateInterval(start: now.addingTimeInterval(.days(-7)), end: now)
    }

    static var lastTwoWeeks: DateInterval {
        let now = Date()
        return DateInterval(start: now.addingTimeInterval(.days(-14)), end: now)
    }

    static var lastMonth: DateInterval {
        let now = Date()
        return DateInterval(start: now.addingTimeInterval(.days(-30)), end: now)
    }

    static var lastDay: DateInterval {
        let now = Date()
        return DateInterval(start: now.addingTimeInterval(.hours(-24)), end: now)
    }

    static var lastSixHours: DateInterval {
        let now = Date()
        return DateInterval(start: now.addingTimeInterval(.hours(-6)), end: now)
    }

}
