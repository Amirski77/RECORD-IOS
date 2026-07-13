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
    
    private var utcCal: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }
    
    // Did the user post today (UTC) ?
    var postedToday: Bool {
        guard let last = lastPostDate else {return false}
        return utcCal.isDate(last, inSameDayAs: Streak.todayUTC)
    }
    
    // Did they post yesterday? (streak still alive, just owes today)
    var PostedYesterday: Bool {
        guard let last = lastPostDate else {return false}
        let yesterday = utcCal.date(byAdding: .day, value: -1, to: Streak.todayUTC)!
        return utcCal.isDate(last, inSameDayAs: yesterday)
    }
    
    // The streak is broken if the last post was NEITHER today NOR yesterday.
    var isBroken: Bool {
        guard lastPostDate != nil else {return true} // never posted
        return !postedToday && !PostedYesterday
    }
    
    // The TRUE count — 0 if broken, otherwise the stored count.
    var effectiveCount: Int {
        isBroken ? 0 : count
    }
    
    // Which visual stare are we in?
    var state: StreakState {
        if effectiveCount == 0 {return .broken}
        if postedToday {
            return effectiveCount == 1 ? .dayOne : .active
        }
        // streak exists but haven't posted today
        return .atRisk // posted yesterday, posted today
    }
}
