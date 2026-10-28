import Foundation

/// Converts local calendar days to persisted keys and traverses real dates across DST and year edges.
struct PostCalendar: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func daykey(for date: Date) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: date))
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }

    func date(for daykey: Int) -> Date? {
        let parts = DateComponents(year: daykey / 10_000, month: daykey / 100 % 100, day: daykey % 100)
        guard let date = calendar.date(from: parts), self.daykey(for: date) == daykey else { return nil }
        return calendar.startOfDay(for: date)
    }

    func previousDay(before date: Date) -> Date? {
        calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))
    }

    func streak(in record: HouseholdRecord, through date: Date) -> Int {
        var cursor = calendar.startOfDay(for: date)
        if !PostFold.fold(record, daykey: daykey(for: cursor)).isComplete {
            guard let previous = previousDay(before: cursor) else { return 0 }
            cursor = previous
        }
        var count = 0
        while PostFold.fold(record, daykey: daykey(for: cursor)).isComplete {
            count += 1
            guard let previous = previousDay(before: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
