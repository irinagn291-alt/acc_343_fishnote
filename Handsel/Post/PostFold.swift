import Foundation

/// Pure aggregate fold and command interpreter. The UI cannot bypass beckon-then-hand rules.
enum PostFold {
    private struct Event {
        let sequence: Int
        let petID: UUID?
        let isHand: Bool
    }

    static func fold(_ record: HouseholdRecord, daykey: Int) -> Post {
        let obligations = record.days.first { $0.daykey == daykey }?.routines ?? []
        let owed = obligations.filter(\.isOwed)
        let hands = record.handMarks.filter { mark in
            mark.daykey == daykey && obligations.contains {
                $0.routineID == mark.routineID && $0.petID == mark.petID
            }
        }.sorted { $0.sequence < $1.sequence }
        let events = record.beckonMarks.filter { $0.daykey == daykey }.map {
            Event(sequence: $0.sequence, petID: $0.petID, isHand: false)
        } + hands.map { Event(sequence: $0.sequence, petID: $0.petID, isHand: true) }
        let pending = events.sorted { $0.sequence < $1.sequence }.reduce(nil as UUID?) { _, event in
            event.isHand ? nil : event.petID
        }
        let completedIDs = Set(hands.map(\.routineID))
        let remaining = owed.filter { !completedIDs.contains($0.routineID) }
        let phase: PostPhase
        if !owed.isEmpty && remaining.isEmpty {
            phase = .shut
        } else if let pending, remaining.contains(where: { $0.petID == pending }) {
            phase = .beckoned(petID: pending)
        } else {
            phase = .idle
        }
        return Post(daykey: daykey, phase: phase, obligations: obligations, hands: hands)
    }

    static func apply(_ action: PostAction, to original: HouseholdRecord, daykey: Int,
                      now: Date = .now) throws -> PostTransition {
        guard PostCalendar().date(for: daykey) != nil else { throw PostRefusal.invalidDay }
        var record = original
        record.prepareDay(daykey)
        if record.pets.filter(\.isActive).isEmpty {
            recordBareIfEmpty(in: &record, daykey: daykey, now: now)
            switch action {
            case .hand, .beckon:
                return PostTransition(record: record, effect: .bare, refusal: .emptyHousehold)
            default: break
            }
        }
        let post = fold(record, daykey: daykey)
        var effect: PostEffect = .none
        switch action {
        case .openDay: break
        case let .beckon(petID):
            guard post.phase != .shut else { throw PostRefusal.shut }
            guard post.phase == .idle else { throw PostRefusal.alreadyBeckoned }
            try requirePet(petID, in: record)
            guard post.remaining.contains(where: { $0.petID == petID }) else { throw PostRefusal.noRoutine }
            record.beckonMarks.append(BeckonMark(id: UUID(), petID: petID, daykey: daykey,
                                                 sequence: record.nextSequence, createdAt: now))
            effect = .beckoned
        case let .hand(petID):
            guard post.phase != .shut else { throw PostRefusal.shut }
            guard let beckonedID = post.beckonedPetID else { throw PostRefusal.idle }
            try requirePet(petID, in: record)
            if petID != beckonedID {
                record.missMarks.append(MissMark(id: UUID(), petID: petID, beckonedPetID: beckonedID,
                                                daykey: daykey, sequence: record.nextSequence, createdAt: now))
                effect = .missed
            } else {
                guard let routine = post.nextRoutine else { throw PostRefusal.noRoutine }
                let hand = HandMark(id: UUID(), petID: petID, routineID: routine.routineID,
                                    daykey: daykey, sequence: record.nextSequence, createdAt: now)
                record.handMarks.append(hand)
                effect = .handed(handID: hand.id)
            }
        case .undoLatestHand:
            record = try UndoLatestHand.apply(to: record, daykey: daykey, now: now)
            effect = .undone
        case var .savePet(pet):
            pet.name = try validName(pet.name)
            record.pets.removeAll { $0.id == pet.id }
            record.pets.append(pet)
            record.prepareDay(daykey, refresh: true)
        case var .saveRoutine(routine):
            routine.name = try validName(routine.name)
            guard routine.order >= 0 else { throw PostRefusal.invalidOrder }
            guard record.pets.contains(where: { $0.id == routine.petID }) else { throw PostRefusal.unknownPet }
            // Moving a logged round would detach its care log. Ask for a new routine instead.
            if let existing = record.routines.first(where: { $0.id == routine.id }),
               existing.petID != routine.petID,
               record.handMarks.contains(where: { $0.daykey == daykey && $0.routineID == routine.id }) {
                throw PostRefusal.routineHasLog
            }
            record.routines.removeAll { $0.id == routine.id }
            record.routines.append(routine)
            record.prepareDay(daykey, refresh: true)
        case let .removePet(petID):
            guard record.pets.contains(where: { $0.id == petID }) else { throw PostRefusal.unknownPet }
            record.routines.removeAll { $0.petID == petID }
            record.pets.removeAll { $0.id == petID }
            record.prepareDay(daykey, refresh: true)
        case let .removeRoutine(routineID):
            guard record.routines.contains(where: { $0.id == routineID }) else { throw PostRefusal.unknownRoutine }
            record.routines.removeAll { $0.id == routineID }
            record.prepareDay(daykey, refresh: true)
        case .completeOnboarding: record.onboardingComplete = true
        case .restartOnboarding: record.onboardingComplete = false
        }
        // Hand and obligation edits persist the same Shut transition atomically.
        let updatedPost = fold(record, daykey: daykey)
        if updatedPost.isComplete,
           !post.isComplete || !record.shutMarks.contains(where: { $0.daykey == daykey }),
           let hand = updatedPost.latestUndoableHand {
            record.shutMarks.append(ShutMark(id: UUID(), handMarkID: hand.id, daykey: daykey,
                                            sequence: record.nextSequence, createdAt: now))
        }
        // Edits can make the household empty. Bare belongs to that same transaction.
        if recordBareIfEmpty(in: &record, daykey: daykey, now: now) { effect = .bare }
        return PostTransition(record: record, effect: effect, refusal: nil)
    }

    @discardableResult
    private static func recordBareIfEmpty(in record: inout HouseholdRecord, daykey: Int, now: Date) -> Bool {
        guard !record.pets.contains(where: \.isActive),
              !record.bareRecords.contains(where: { $0.daykey == daykey }) else { return false }
        record.bareRecords.append(Bare(id: UUID(), daykey: daykey, createdAt: now))
        return true
    }

    private static func requirePet(_ id: UUID, in record: HouseholdRecord) throws {
        guard record.pets.contains(where: { $0.id == id && $0.isActive }) else { throw PostRefusal.unknownPet }
    }

    private static func validName(_ name: String) throws -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw PostRefusal.invalidName }
        return name
    }
}
