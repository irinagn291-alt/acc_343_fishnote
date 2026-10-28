import Foundation

/// Versioned persistence projection of the household. Phase, totals and streak are always derived.
struct HouseholdRecord: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var pets: [Pet] = []
    var routines: [Routine] = []
    var days: [DayObligations] = []
    var beckonMarks: [BeckonMark] = []
    var handMarks: [HandMark] = []
    var missMarks: [MissMark] = []
    var shutMarks: [ShutMark] = []
    var bareRecords: [Bare] = []
    var onboardingComplete = false
    var demoVersion: String?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, pets, routines, days, beckonMarks, handMarks, missMarks
        case shutMarks, bareRecords, onboardingComplete, demoVersion
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decode(Int.self, forKey: .schemaVersion)
        switch version {
        case 1:
            schemaVersion = version
            pets = try values.decode([Pet].self, forKey: .pets)
            routines = try values.decode([Routine].self, forKey: .routines)
            days = try values.decode([DayObligations].self, forKey: .days)
            beckonMarks = try values.decode([BeckonMark].self, forKey: .beckonMarks)
            handMarks = try values.decode([HandMark].self, forKey: .handMarks)
            missMarks = try values.decode([MissMark].self, forKey: .missMarks)
            shutMarks = try values.decode([ShutMark].self, forKey: .shutMarks)
            bareRecords = try values.decode([Bare].self, forKey: .bareRecords)
            onboardingComplete = try values.decode(Bool.self, forKey: .onboardingComplete)
            demoVersion = try values.decodeIfPresent(String.self, forKey: .demoVersion)
        default:
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: values,
                                                  debugDescription: "Unsupported household schema \(version).")
        }
        try validate()
    }

    func validate() throws {
        let sequences = beckonMarks.map(\.sequence) + handMarks.map(\.sequence)
            + missMarks.map(\.sequence) + shutMarks.map(\.sequence)
        guard schemaVersion == 1,
              Set(pets.map(\.id)).count == pets.count,
              Set(routines.map(\.id)).count == routines.count,
              Set(days.map(\.daykey)).count == days.count,
              Set(sequences).count == sequences.count,
              sequences.allSatisfy({ $0 > 0 && $0 < Int.max - 2 }),
              pets.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              routines.allSatisfy({ routine in
                  routine.order >= 0 && !routine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && pets.contains { $0.id == routine.petID }
              }),
              days.allSatisfy({ day in
                  PostCalendar().date(for: day.daykey) != nil
                      && Set(day.routines.map(\.routineID)).count == day.routines.count
              }),
              handMarks.allSatisfy({ hand in
                  days.contains { day in
                      day.daykey == hand.daykey && day.routines.contains {
                          $0.routineID == hand.routineID && $0.petID == hand.petID
                      }
                  }
              }) else {
            throw HouseholdStorageError.invalidRecord
        }
        let handKeys = handMarks.map { "\($0.daykey):\($0.routineID)" }
        guard Set(handKeys).count == handKeys.count else { throw HouseholdStorageError.invalidRecord }
    }

    var nextSequence: Int {
        let values = beckonMarks.map(\.sequence) + handMarks.map(\.sequence)
            + missMarks.map(\.sequence) + shutMarks.map(\.sequence)
        return (values.max() ?? 0) + 1
    }

    mutating func prepareDay(_ daykey: Int, refresh: Bool = false) {
        if !refresh && days.contains(where: { $0.daykey == daykey }) { return }
        let obligations = routines.compactMap { routine -> RoutineObligation? in
            guard routine.isActive, let pet = pets.first(where: { $0.id == routine.petID && $0.isActive }) else {
                return nil
            }
            return RoutineObligation(routineID: routine.id, petID: pet.id, petName: pet.name,
                                     routineName: routine.name, order: routine.order)
        }.sorted {
            $0.order == $1.order ? $0.routineID.uuidString < $1.routineID.uuidString : $0.order < $1.order
        }
        // Keep already logged obligations on today's contract when their definition is removed.
        // Archived entries retain history and event ordering, but no longer count as owed care.
        let loggedIDs = Set(handMarks.filter { $0.daykey == daykey }.map(\.routineID))
        let previous = days.first { $0.daykey == daykey }?.routines ?? []
        let retained = previous.filter { old in
            loggedIDs.contains(old.routineID) && !obligations.contains { $0.routineID == old.routineID }
        }.map { old in
            var archived = old
            archived.isOwed = false
            return archived
        }
        days.removeAll { $0.daykey == daykey }
        days.append(DayObligations(daykey: daykey, routines: obligations + retained))
    }
}
