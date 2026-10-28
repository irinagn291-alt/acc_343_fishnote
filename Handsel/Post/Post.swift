import Foundation

/// The complete phase algebra. No view or store keeps an independent mutable phase.
enum PostPhase: Equatable, Sendable {
    case idle
    case beckoned(petID: UUID)
    case shut
}

/// Read-only result of folding the dated obligations and persisted marks.
struct Post: Equatable, Sendable {
    let daykey: Int
    let phase: PostPhase
    let obligations: [RoutineObligation]
    let hands: [HandMark]

    // Archived obligations remain visible in history but never count as work owed today.
    var owedObligations: [RoutineObligation] { obligations.filter(\.isOwed) }
    var completedRoutineIDs: Set<UUID> { Set(hands.map(\.routineID)) }
    var remaining: [RoutineObligation] { owedObligations.filter { !completedRoutineIDs.contains($0.routineID) } }
    var completedCount: Int { owedObligations.count - remaining.count }
    var isComplete: Bool { !owedObligations.isEmpty && remaining.isEmpty }
    var latestUndoableHand: HandMark? {
        hands.last { hand in
            owedObligations.contains { $0.routineID == hand.routineID && $0.petID == hand.petID }
        }
    }
    var beckonedPetID: UUID? {
        if case let .beckoned(petID) = phase { return petID }
        return nil
    }
    var nextRoutine: RoutineObligation? { remaining.first { $0.petID == beckonedPetID } }
    var canHand: Bool { nextRoutine != nil && beckonedPetID != nil }
}

/// Refusals carry a concrete next action and never mutate a completed care record.
enum PostRefusal: Error, Equatable, Sendable, LocalizedError {
    case idle, shut, alreadyBeckoned, unknownPet, noRoutine, emptyHousehold, noHand
    case invalidName, invalidOrder, unknownRoutine, invalidDay, routineHasLog

    var errorDescription: String? {
        switch self {
        case .idle: "Beckon a pet before handing the care token."
        case .shut: "This day is complete. Undo the latest logged round to reopen it."
        case .alreadyBeckoned: "Hand to the pet already beckoned before beckoning another."
        case .unknownPet: "Choose an active pet from Pets."
        case .noRoutine: "This pet has no rounds left. Beckon a pet that still owes care."
        case .emptyHousehold: "Add a pet and a care round to begin."
        case .noHand: "There is no current care round to undo. Archived care stays in the log."
        case .invalidName: "Enter a name before saving."
        case .invalidOrder: "Use a care-round order of zero or greater."
        case .unknownRoutine: "Choose a care round from Routines."
        case .routineHasLog: "This round already has a log today. Add a new care round for the other pet."
        case .invalidDay: "Choose a valid calendar day."
        }
    }
}

/// Commands enter one pure transaction before crossing the persistence seam.
enum PostAction: Sendable {
    case openDay
    case beckon(petID: UUID)
    case hand(petID: UUID)
    case undoLatestHand
    case savePet(Pet)
    case saveRoutine(Routine)
    case removePet(UUID)
    case removeRoutine(UUID)
    case completeOnboarding
    case restartOnboarding
}

/// A success effect is emitted by presentation only after this whole transaction is durable.
enum PostEffect: Equatable, Sendable {
    case none, beckoned, handed(handID: UUID), missed, undone, bare
}

struct PostTransition: Sendable {
    let record: HouseholdRecord
    let effect: PostEffect
    let refusal: PostRefusal?
}
