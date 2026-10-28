import Foundation

/// Simulator-only demo factory. All rounds use the same command fold as production care.
enum HouseholdSeed {
    static func prepare(_ original: HouseholdRecord, now: Date, calendar: PostCalendar) throws -> HouseholdRecord {
        #if targetEnvironment(simulator)
        guard original.demoVersion != HouseholdStore.demoKey,
              original.pets.isEmpty, original.routines.isEmpty, original.days.isEmpty,
              !original.onboardingComplete else { return original }
        var record = original
        let pets = [Pet(name: "Mabel"), Pet(name: "Otis"), Pet(name: "Pip")]
        record.pets = pets
        record.routines = [
            Routine(petID: pets[0].id, name: "Breakfast", order: 0),
            Routine(petID: pets[0].id, name: "Morning walk", order: 1),
            Routine(petID: pets[1].id, name: "Fresh water", order: 2),
            Routine(petID: pets[1].id, name: "Breakfast", order: 3),
            Routine(petID: pets[2].id, name: "Clean bedding", order: 4)
        ]
        var cursor = now
        for _ in 0..<3 {
            guard let previous = calendar.previousDay(before: cursor) else { break }
            cursor = previous
            let key = calendar.daykey(for: cursor)
            record = try PostFold.apply(.openDay, to: record, daykey: key, now: cursor).record
            while let next = PostFold.fold(record, daykey: key).remaining.first {
                record = try PostFold.apply(.beckon(petID: next.petID), to: record, daykey: key, now: cursor).record
                record = try PostFold.apply(.hand(petID: next.petID), to: record, daykey: key, now: cursor).record
            }
        }
        record.onboardingComplete = true
        record.demoVersion = HouseholdStore.demoKey
        return try PostFold.apply(.beckon(petID: pets[0].id), to: record,
                                  daykey: calendar.daykey(for: now), now: now).record
        #else
        return original
        #endif
    }
}
