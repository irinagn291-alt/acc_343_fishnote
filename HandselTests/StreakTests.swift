import Foundation
import Testing
@testable import Handsel

@Suite("Local calendar and streak")
struct StreakTests {
    private func clock(zone: String = "America/New_York") throws -> PostCalendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        return PostCalendar(calendar: calendar)
    }

    @Test func walksYearBoundaryAndStopsAtMissingDay() throws {
        let calendar = try clock()
        var record = try PostFixture.household(day: 20251230)
        for key in [20251230, 20251231, 20260101] { record = try PostFixture.complete(record, day: key) }
        let date = try #require(calendar.date(for: 20260101))
        #expect(calendar.streak(in: record, through: date) == 3)
        let next = try #require(calendar.date(for: 20260102))
        #expect(calendar.streak(in: record, through: next) == 3)
        let gap = try #require(calendar.date(for: 20260103))
        #expect(calendar.streak(in: record, through: gap) == 0)
    }

    @Test func walksDSTAndLeapDayUsingCalendarArithmetic() throws {
        let calendar = try clock()
        let afterDST = try #require(calendar.date(for: 20260309))
        let before = try #require(calendar.previousDay(before: afterDST))
        #expect(calendar.daykey(for: before) == 20260308)
        #expect(afterDST.timeIntervalSince(before) == 23 * 60 * 60)
        let march = try #require(calendar.date(for: 20240301))
        let leap = try #require(calendar.previousDay(before: march))
        #expect(calendar.daykey(for: leap) == 20240229)
        var record = try PostFixture.household(day: 20260307)
        for key in [20260307, 20260308, 20260309] { record = try PostFixture.complete(record, day: key) }
        #expect(calendar.streak(in: record, through: afterDST) == 3)
    }

    @Test func undoBreaksStreakAndInactiveRoundsNeverBecomeRetroactivelyOwed() throws {
        let calendar = try clock()
        var record = try PostFixture.household(day: 20261024)
        for key in [20261024, 20261025, 20261026] { record = try PostFixture.complete(record, day: key) }
        record = try PostFixture.applying(.undoLatestHand, to: record, day: 20261025)
        let date = try #require(calendar.date(for: 20261026))
        #expect(calendar.streak(in: record, through: date) == 1)
        record = try PostFixture.applying(.saveRoutine(Routine(petID: PostFixture.firstID, name: "Evening care")), to: record)
        #expect(PostFold.fold(record, daykey: 20261024).isComplete)
        #expect(!PostFold.fold(record, daykey: 20261026).isComplete)
    }

    @Test func dateKeysUseLocalStartOfDay() throws {
        let calendar = try clock(zone: "Pacific/Auckland")
        let instant = Date(timeIntervalSince1970: 1_767_182_400) // 2025-12-31 12:00 UTC
        let key = calendar.daykey(for: instant)
        #expect(key == 20260101)
        #expect(calendar.date(for: 20261301) == nil)
    }
}
