//
//  Streak.swift
//  RECORD
//
//  Created by Amir Rashidov on 11.07.2026.
//

import Foundation

// The 4 visual states from the spec.
enum StreakState {
    case active // posted today ,streak >=2 → bright green
    case dayOne // streak ==1 → neutral
    case atRisk // streak >=1, NOT POSTED TODAY → amber
    case broken // streak == 0 → gray
}

struct Streak {
    let count: Int
    let lastPostDate: Date? // from profiles.last_post_date
    
    // UTC "today" as plain date (matches your day boundary)
    static var todayUTC: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.startOfDay(for: Date())
    }
    
    // Did the user post today (UTC) ?
    var postedToday: Bool {
        guard let last = lastPostDate else {return false}
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.isDate(last, inSameDayAs: Streak.todayUTC)
    }
    
    // Which visual stare are we in?
    var state: StreakState {
        if count == 0 {return .broken}
        if postedToday {
            return count == 1 ? .dayOne : .active
        }
        // streak exists but haven't posted today
        return .atRisk
    }
}
