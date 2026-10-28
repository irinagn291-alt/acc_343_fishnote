import Foundation

/// An ordered care round owned by one Pet. The day snapshot freezes the obligation.
struct Routine: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var petID: UUID
    var name: String
    var isActive: Bool
    var order: Int

    init(id: UUID = UUID(), petID: UUID, name: String, isActive: Bool = true, order: Int = 0) {
        self.id = id
        self.petID = petID
        self.name = name
        self.isActive = isActive
        self.order = order
    }
}

/// Immutable dated care contract, including labels for history after a Pet or Routine is removed.
struct RoutineObligation: Codable, Equatable, Identifiable, Sendable {
    var id: UUID { routineID }
    let routineID: UUID
    let petID: UUID
    let petName: String
    let routineName: String
    let order: Int
    var isOwed = true
}

/// Records what was owed on an observed day; an unobserved day never counts as complete.
struct DayObligations: Codable, Equatable, Sendable {
    let daykey: Int
    var routines: [RoutineObligation]
}
