//
//  StreakTests.swift
//  RECORDTests
//
//  Streak is pure logic over dates with four visual states, which makes it
//  exactly the kind of code that is cheap to test and expensive to get wrong
//  by hand. The UTC day boundary is the whole app's definition of "today", so
//  these cases are really testing the product rule, not the struct.
//
//  Anchored to Streak.todayUTC — the same clock the code under test reads —
//  so the only way these could flake is if UTC midnight landed between two
//  lines of one test.
//

import Testing
import Foundation
@testable import RECORD

private var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}

private func daysAgo(_ n: Int) -> Date {
    utcCalendar.date(byAdding: .day, value: -n, to: Streak.todayUTC)!
}

@Suite("Streak")
struct StreakTests {

    @Test("never posted reads as broken, not as a zero streak")
    func neverPosted() {
        let streak = Streak(count: 0, lastPostDate: nil)
        #expect(streak.isBroken)
        #expect(streak.effectiveCount == 0)
        #expect(streak.state == .broken)
        #expect(!streak.postedToday)
    }

    @Test("posted today, one day in — day one, not active")
    func dayOne() {
        let streak = Streak(count: 1, lastPostDate: daysAgo(0))
        #expect(streak.postedToday)
        #expect(streak.effectiveCount == 1)
        #expect(streak.state == .dayOne)
    }

    @Test("posted today with a run going — active")
    func active() {
        let streak = Streak(count: 7, lastPostDate: daysAgo(0))
        #expect(streak.postedToday)
        #expect(streak.effectiveCount == 7)
        #expect(streak.state == .active)
    }

    @Test("posted yesterday only — alive but at risk")
    func atRisk() {
        let streak = Streak(count: 7, lastPostDate: daysAgo(1))
        #expect(!streak.postedToday)
        #expect(streak.PostedYesterday)
        #expect(!streak.isBroken)
        #expect(streak.effectiveCount == 7, "yesterday's streak still counts today")
        #expect(streak.state == .atRisk)
    }

    @Test("a two-day gap zeroes the count even when the server still stores it")
    func brokenByGap() {
        // The important case: profiles.current_streak is only reset on the next
        // post, so the stored number goes stale. effectiveCount is what the UI
        // must trust.
        let streak = Streak(count: 30, lastPostDate: daysAgo(2))
        #expect(streak.isBroken)
        #expect(streak.effectiveCount == 0)
        #expect(streak.state == .broken)
    }

    @Test("a long gap is broken too", arguments: [3, 7, 30, 365])
    func brokenByLongerGap(days: Int) {
        let streak = Streak(count: 12, lastPostDate: daysAgo(days))
        #expect(streak.isBroken)
        #expect(streak.effectiveCount == 0)
    }

    @Test("todayUTC is midnight in UTC, not local midnight")
    func todayIsUTCMidnight() {
        let parts = utcCalendar.dateComponents([.hour, .minute, .second], from: Streak.todayUTC)
        #expect(parts.hour == 0)
        #expect(parts.minute == 0)
        #expect(parts.second == 0)
    }
}
