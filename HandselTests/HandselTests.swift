import Foundation
import Testing
@testable import Handsel

/// Real aggregate fixtures use production commands, avoiding a parallel implementation of the mechanic.
enum PostFixture {
    static let day = 20261026
    static let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    static let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()

    static func household(rounds: Int = 2, day: Int = day) throws -> HouseholdRecord {
        var record = HouseholdRecord()
        record.pets = [Pet(id: firstID, name: "Mabel"), Pet(id: secondID, name: "Otis")]
        record.routines = (0..<rounds).map { index in
            Routine(petID: index == 0 ? firstID : secondID, name: "Round \(index)", order: index)
        }
        return try applying(.openDay, to: record, day: day)
    }

    static func applying(_ action: PostAction, to record: HouseholdRecord, day: Int = day) throws -> HouseholdRecord {
        try PostFold.apply(action, to: record, daykey: day).record
    }

    static func complete(_ original: HouseholdRecord, day: Int = day) throws -> HouseholdRecord {
        var record = try applying(.openDay, to: original, day: day)
        while let next = PostFold.fold(record, daykey: day).remaining.first {
            record = try applying(.beckon(petID: next.petID), to: record, day: day)
            record = try applying(.hand(petID: next.petID), to: record, day: day)
        }
        return record
    }
}

@Suite("Post fold")
struct PostFoldTests {
    @Test func handRequiresBeckonAndIsPure() throws {
        let record = try PostFixture.household()
        #expect(throws: PostRefusal.idle) {
            try PostFixture.applying(.hand(petID: PostFixture.firstID), to: record)
        }
        #expect(record.handMarks.isEmpty)
        #expect(PostFold.fold(record, daykey: PostFixture.day).phase == .idle)
    }

    @Test func emptyHouseholdWritesBareOnceAndCannotComplete() throws {
        let first = try PostFold.apply(.hand(petID: UUID()), to: HouseholdRecord(), daykey: PostFixture.day)
        #expect(first.refusal == .emptyHousehold)
        #expect(first.effect == .bare)
        #expect(first.record.bareRecords.count == 1)
        let second = try PostFold.apply(.hand(petID: UUID()), to: first.record, daykey: PostFixture.day)
        #expect(second.record.bareRecords.count == 1)
        #expect(!PostFold.fold(second.record, daykey: PostFixture.day).isComplete)
        #expect(second.record.shutMarks.isEmpty)
    }

    @Test func petWithoutRoutinesCannotBeBeckonedOrComplete() throws {
        let record = try PostFixture.household(rounds: 0)
        #expect(throws: PostRefusal.noRoutine) {
            try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: record)
        }
        #expect(!PostFold.fold(record, daykey: PostFixture.day).isComplete)
    }

    @Test func nextUndoneRoundUsesStableOrderThenStableID() throws {
        var record = try PostFixture.household(rounds: 0)
        let low = UUID(uuidString: "10000000-0000-0000-0000-000000000001") ?? UUID()
        let high = UUID(uuidString: "10000000-0000-0000-0000-000000000002") ?? UUID()
        record.routines = [
            Routine(id: high, petID: PostFixture.firstID, name: "Water", order: 1),
            Routine(petID: PostFixture.firstID, name: "Walk", order: 2),
            Routine(id: low, petID: PostFixture.firstID, name: "Food", order: 1)
        ]
        record.prepareDay(PostFixture.day, refresh: true)
        record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: record)
        #expect(PostFold.fold(record, daykey: PostFixture.day).nextRoutine?.routineID == low)
        record = try PostFixture.applying(.hand(petID: PostFixture.firstID), to: record)
        #expect(record.handMarks.first?.routineID == low)
        #expect(PostFold.fold(record, daykey: PostFixture.day).phase == .idle)
        record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: record)
        #expect(PostFold.fold(record, daykey: PostFixture.day).nextRoutine?.routineID == high)
    }

    @Test func handToOtherPetWritesMissAndKeepsBeckoned() throws {
        let initial = try PostFixture.household()
        let beckoned = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: initial)
        let result = try PostFold.apply(.hand(petID: PostFixture.secondID), to: beckoned, daykey: PostFixture.day)
        #expect(result.effect == .missed)
        #expect(result.record.missMarks.count == 1)
        #expect(result.record.handMarks.isEmpty)
        #expect(PostFold.fold(result.record, daykey: PostFixture.day).phase == .beckoned(petID: PostFixture.firstID))
    }

    @Test func refusesUnknownInactiveAndAlreadyBeckonedPets() throws {
        var record = try PostFixture.household()
        #expect(throws: PostRefusal.unknownPet) {
            try PostFixture.applying(.beckon(petID: UUID()), to: record)
        }
        record.pets[1].isActive = false
        #expect(throws: PostRefusal.unknownPet) {
            try PostFixture.applying(.beckon(petID: PostFixture.secondID), to: record)
        }
        record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: record)
        #expect(throws: PostRefusal.alreadyBeckoned) {
            try PostFixture.applying(.beckon(petID: PostFixture.secondID), to: record)
        }
        #expect(throws: PostRefusal.unknownPet) {
            try PostFixture.applying(.hand(petID: UUID()), to: record)
        }
    }

    @Test func finalHandAndShutAreOneTransactionAndShutRefusesBothVerbs() throws {
        let record = try PostFixture.household(rounds: 1)
        let beckoned = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: record)
        let result = try PostFold.apply(.hand(petID: PostFixture.firstID), to: beckoned, daykey: PostFixture.day)
        #expect(result.record.handMarks.count == 1)
        #expect(result.record.shutMarks.count == 1)
        #expect(result.record.shutMarks.first?.handMarkID == result.record.handMarks.first?.id)
        #expect(PostFold.fold(result.record, daykey: PostFixture.day).phase == .shut)
        #expect(throws: PostRefusal.shut) {
            try PostFixture.applying(.hand(petID: PostFixture.firstID), to: result.record)
        }
        #expect(throws: PostRefusal.shut) {
            try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: result.record)
        }
    }

    @Test func completeIffEveryOwedRoutineHasMatchingHand() throws {
        let record = try PostFixture.household(rounds: 3)
        // Check every subset, including a misleading ShutMark with missing care.
        let complete = try PostFixture.complete(record)
        for mask in 0..<(1 << complete.handMarks.count) {
            var candidate = complete
            candidate.handMarks = complete.handMarks.enumerated().compactMap { index, hand in
                mask & (1 << index) == 0 ? nil : hand
            }
            let post = PostFold.fold(candidate, daykey: PostFixture.day)
            #expect(post.isComplete == (candidate.handMarks.count == 3))
            #expect((post.phase == .shut) == post.isComplete)
        }
    }

    @Test func undoLatestHandReopensShutAndRehandsSameRound() throws {
        let initial = try PostFixture.household()
        let complete = try PostFixture.complete(initial)
        let undone = try PostFixture.applying(.undoLatestHand, to: complete)
        #expect(undone.handMarks.count == 1)
        #expect(undone.shutMarks.isEmpty)
        #expect(PostFold.fold(undone, daykey: PostFixture.day).phase == .beckoned(petID: PostFixture.secondID))
        let restored = try PostFixture.applying(.hand(petID: PostFixture.secondID), to: undone)
        #expect(PostFold.fold(restored, daykey: PostFixture.day).isComplete)
        #expect(restored.shutMarks.count == 1)
    }

    @Test func undoFromIdleRestoresAffectedPetAndEmptyUndoRefused() throws {
        var record = try PostFixture.household()
        #expect(throws: PostRefusal.noHand) { try PostFixture.applying(.undoLatestHand, to: record) }
        record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: record)
        record = try PostFixture.applying(.hand(petID: PostFixture.firstID), to: record)
        record = try PostFixture.applying(.beckon(petID: PostFixture.secondID), to: record)
        record = try PostFixture.applying(.undoLatestHand, to: record)
        #expect(PostFold.fold(record, daykey: PostFixture.day).phase == .beckoned(petID: PostFixture.firstID))
    }

    @Test func roundTripReplaysPhaseRatherThanPersistingIt() throws {
        let record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: PostFixture.household())
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(HouseholdRecord.self, from: data)
        #expect(PostFold.fold(decoded, daykey: PostFixture.day) == PostFold.fold(record, daykey: PostFixture.day))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("\"phase\""))
        #expect(!json.contains("\"streak\""))
    }

    @Test func editsValidateNamesOrdersAndOwnership() throws {
        let record = try PostFixture.household()
        #expect(throws: PostRefusal.invalidName) { try PostFixture.applying(.savePet(Pet(name: " \n")), to: record) }
        #expect(throws: PostRefusal.invalidName) {
            try PostFixture.applying(.saveRoutine(Routine(petID: PostFixture.firstID, name: "")), to: record)
        }
        #expect(throws: PostRefusal.invalidOrder) {
            try PostFixture.applying(.saveRoutine(Routine(petID: PostFixture.firstID, name: "Water", order: -1)), to: record)
        }
        #expect(throws: PostRefusal.unknownPet) {
            try PostFixture.applying(.saveRoutine(Routine(petID: UUID(), name: "Water")), to: record)
        }
        let saved = try PostFixture.applying(.savePet(Pet(name: "  Hazel  ")), to: record)
        #expect(saved.pets.last?.name == "Hazel")
    }

    @Test func removalAndDeactivationDoNotRewritePreviousDays() throws {
        let yesterday = 20261025
        var record = try PostFixture.complete(PostFixture.household(day: yesterday), day: yesterday)
        let past = PostFold.fold(record, daykey: yesterday)
        var pet = try #require(record.pets.first)
        pet.isActive = false
        record = try PostFixture.applying(.savePet(pet), to: record)
        record = try PostFixture.applying(.removePet(PostFixture.secondID), to: record)
        record = try PostFixture.applying(.savePet(Pet(name: "New pet")), to: record)
        #expect(PostFold.fold(record, daykey: yesterday) == past)
        #expect(!PostFold.fold(record, daykey: PostFixture.day).isComplete)
        try record.validate()
    }

    @Test func removingAllPetsTodayCannotLeaveDayComplete() throws {
        var record = try PostFixture.complete(PostFixture.household())
        record = try PostFixture.applying(.removePet(PostFixture.firstID), to: record)
        record = try PostFixture.applying(.removePet(PostFixture.secondID), to: record)
        record = try PostFixture.applying(.openDay, to: record)
        #expect(!PostFold.fold(record, daykey: PostFixture.day).isComplete)
        #expect(record.bareRecords.count == 1)
        try record.validate()
    }

    @Test func invalidDayIsRefused() throws {
        #expect(throws: PostRefusal.invalidDay) {
            try PostFixture.applying(.openDay, to: HouseholdRecord(), day: 20260230)
        }
    }
}
