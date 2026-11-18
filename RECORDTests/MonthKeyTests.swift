//
//  MonthKeyTests.swift
//  RECORDTests
//
//  monthKey decides which Spotify playlist a post lands in. It has to agree
//  with the UTC day boundary used by Streak and by the one_post_per_utc_day
//  index, otherwise a post made late on the last of the month ends up in the
//  wrong playlist — and the edge function, which does its own UTC month
//  arithmetic, would disagree with the app.
//

import Testing
import Foundation
@testable import RECORD

@Suite("monthKey")
struct MonthKeyTests {

    private func utc(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: iso)!
    }

    @Test("formats as YYYY-MM with a leading zero")
    func formatsPadded() {
        #expect(monthKey(for: utc("2026-07-14T13:00:00Z")) == "2026-07")
        #expect(monthKey(for: utc("2026-01-01T00:00:00Z")) == "2026-01")
        #expect(monthKey(for: utc("2026-12-31T23:59:59Z")) == "2026-12")
    }

    @Test("the boundary is UTC, so a late-night local post keeps its UTC month")
    func boundaryIsUTC() {
        // 23:30 UTC on the 31st is already the 1st in Almaty (UTC+5), but the
        // record belongs to the month its own dateline shows — the UTC one.
        #expect(monthKey(for: utc("2026-07-31T23:30:00Z")) == "2026-07")
        // And just past UTC midnight it is unambiguously the new month.
        #expect(monthKey(for: utc("2026-08-01T00:30:00Z")) == "2026-08")
    }

    @Test("parses a timestamp with fractional seconds, as Postgres returns")
    func parsesFractionalSeconds() {
        #expect(monthKey(fromCreatedAt: "2026-07-14T13:00:00.123456+00:00") == "2026-07")
    }

    @Test("parses a timestamp without fractional seconds too")
    func parsesPlainSeconds() {
        #expect(monthKey(fromCreatedAt: "2026-07-14T13:00:00+00:00") == "2026-07")
        #expect(monthKey(fromCreatedAt: "2026-07-14T13:00:00Z") == "2026-07")
    }

    @Test("returns nil rather than a wrong month for junk")
    func rejectsJunk() {
        #expect(monthKey(fromCreatedAt: "") == nil)
        #expect(monthKey(fromCreatedAt: "not a date") == nil)
    }

    @Test("agrees with the edge function's month range for a known month")
    func matchesEdgeFunctionRange() {
        // spotify-playlist builds [start, end) as UTC month bounds, then
        // selects posts in that window. Both ends must map back to the key.
        #expect(monthKey(for: utc("2026-02-01T00:00:00Z")) == "2026-02")
        #expect(monthKey(for: utc("2026-02-28T23:59:59Z")) == "2026-02")
        #expect(monthKey(for: utc("2026-03-01T00:00:00Z")) == "2026-03")
    }
}
