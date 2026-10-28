import Foundation
import Testing
@testable import Handsel

@Suite("Archived care and atomic household edits")
struct ArchivedCareTests {
    @Test(arguments: ["removeRoutine", "pauseRoutine", "removePet", "pausePet"])
    func removingLastUnfinishedObligationPersistsShut(edit: String) throws {
        var record = try PostFixture.household()
        record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: record)
        record = try PostFixture.applying(.hand(petID: PostFixture.firstID), to: record)
        record = try PostFixture.applying(.beckon(petID: PostFixture.secondID), to: record)
        let hand = try #require(record.handMarks.last)
        var routine = try #require(record.routines.first { $0.petID == PostFixture.secondID })
        var pet = try #require(record.pets.first { $0.id == PostFixture.secondID })
        routine.isActive = false
        pet.isActive = false
        let action: PostAction
        switch edit {
        case "removeRoutine": action = .removeRoutine(routine.id)
        case "pauseRoutine": action = .saveRoutine(routine)
        case "removePet": action = .removePet(pet.id)
        default: action = .savePet(pet)
        }
        let now = try #require(PostCalendar().date(for: PostFixture.day))
        let result = try PostFold.apply(action, to: record, daykey: PostFixture.day, now: now)
        #expect(result.effect == .none)
        let shut = try #require(result.record.shutMarks.last)
        #expect(result.record.shutMarks.count == 1)
        #expect(shut.handMarkID == hand.id)
        #expect(shut.daykey == PostFixture.day)
        #expect(shut.createdAt == now)
        let beckon = try #require(record.beckonMarks.last)
        #expect(shut.sequence > beckon.sequence)
        let reloaded = try JSONDecoder().decode(HouseholdRecord.self, from: JSONEncoder().encode(result.record))
        try reloaded.validate()
        #expect(PostFold.fold(reloaded, daykey: PostFixture.day).phase == .shut)
        #expect(PostCalendar().streak(in: reloaded, through: now) == 1)
        let observed = try PostFixture.applying(.openDay, to: reloaded)
        #expect(observed.shutMarks == [shut])
        let undone = try PostFixture.applying(.undoLatestHand, to: reloaded)
        #expect(undone.shutMarks.isEmpty)
        #expect(PostFold.fold(undone, daykey: PostFixture.day).phase == .beckoned(petID: hand.petID))
    }

    @Test func closingAgainAfterAddingThenRemovingAnUnfinishedRoundRecordsAnotherTransition() throws {
        let complete = try PostFixture.complete(PostFixture.household(rounds: 1))
        let extra = Routine(petID: PostFixture.firstID, name: "Water")
        let reopened = try PostFixture.applying(.saveRoutine(extra), to: complete)
        #expect(!PostFold.fold(reopened, daykey: PostFixture.day).isComplete)
        let closed = try PostFixture.applying(.removeRoutine(extra.id), to: reopened)
        #expect(closed.shutMarks.count == 2)
        #expect(closed.shutMarks.last?.handMarkID == complete.handMarks.last?.id)
        let renamed = try PostFixture.applying(.savePet(Pet(id: PostFixture.firstID, name: "Hazel")), to: closed)
        #expect(renamed.shutMarks == closed.shutMarks)
    }

    @Test(arguments: [false, true])
    func undoAfterArchivingLatestLogReopensAnOwedRound(pause: Bool) throws {
        var record = try PostFixture.complete(PostFixture.household())
        let archivedHand = try #require(record.handMarks.last)
        var routine = try #require(record.routines.first { $0.id == archivedHand.routineID })
        if pause {
            routine.isActive = false
            record = try PostFixture.applying(.saveRoutine(routine), to: record)
        } else {
            record = try PostFixture.applying(.removeRoutine(routine.id), to: record)
        }
        #expect(PostFold.fold(record, daykey: PostFixture.day).phase == .shut)
        let undone = try PostFixture.applying(.undoLatestHand, to: record)
        let post = PostFold.fold(undone, daykey: PostFixture.day)
        #expect(post.phase == .beckoned(petID: PostFixture.firstID))
        #expect(post.canHand)
        #expect(!post.isComplete)
        #expect(post.completedCount == 0)
        #expect(post.hands == [archivedHand])
        #expect(undone.shutMarks.isEmpty)
        let restored = try PostFixture.applying(.hand(petID: PostFixture.firstID), to: undone)
        #expect(PostFold.fold(restored, daykey: PostFixture.day).isComplete)
        #expect(restored.handMarks.contains(archivedHand))
        try restored.validate()
    }

    @Test(arguments: [false, true])
    func archivedOnlyDayKeepsItsLogAfterReloadWithoutCompleting(pause: Bool) throws {
        var record = try PostFixture.complete(PostFixture.household(rounds: 1))
        let logged = record.handMarks
        var routine = try #require(record.routines.first)
        if pause {
            routine.isActive = false
            record = try PostFixture.applying(.saveRoutine(routine), to: record)
        } else {
            record = try PostFixture.applying(.removeRoutine(routine.id), to: record)
        }
        record = try JSONDecoder().decode(HouseholdRecord.self, from: JSONEncoder().encode(record))
        let post = PostFold.fold(record, daykey: PostFixture.day)
        #expect(post.hands == logged)
        #expect(post.obligations.count == 1)
        #expect(post.obligations.first?.routineName == routine.name)
        #expect(post.obligations.first?.isOwed == false)
        #expect(post.completedRoutineIDs.contains(routine.id))
        #expect(post.completedCount == 0)
        #expect(post.remaining.isEmpty)
        #expect(!post.isComplete)
        #expect(post.latestUndoableHand == nil)
        #expect(throws: PostRefusal.noHand) { try PostFixture.applying(.undoLatestHand, to: record) }
        let observed = try PostFixture.applying(.openDay, to: record)
        #expect(PostFold.fold(observed, daykey: PostFixture.day).hands == logged)
    }

    @Test(arguments: [false, true])
    func lastActivePetEditWritesBareBeforeAnotherCommand(pause: Bool) throws {
        var record = try PostFixture.complete(PostFixture.household())
        let logged = record.handMarks
        record = try PostFixture.applying(.removePet(PostFixture.firstID), to: record)
        #expect(record.bareRecords.isEmpty)
        var pet = try #require(record.pets.first)
        pet.isActive = false
        let result = try PostFold.apply(pause ? .savePet(pet) : .removePet(pet.id),
                                        to: record, daykey: PostFixture.day)
        #expect(result.effect == .bare)
        #expect(result.record.bareRecords.map(\.daykey) == [PostFixture.day])
        let post = PostFold.fold(result.record, daykey: PostFixture.day)
        #expect(!post.isComplete)
        #expect(post.hands == logged)
        #expect(post.obligations.allSatisfy { !$0.isOwed })
        let reopened = try PostFixture.applying(.openDay, to: result.record)
        #expect(reopened.bareRecords == result.record.bareRecords)
        try reopened.validate()
    }

    @Test @MainActor
    func archiveRemainsInPresentationHistoryWhenTodayBecomesEmpty() async throws {
        let now = try #require(PostCalendar().date(for: PostFixture.day))
        let record = try PostFixture.complete(PostFixture.household(rounds: 1))
        let storage = PostTestStorage(record)
        let model = PostPresentation(storage: storage, now: now)
        await model.load(now: now, seedSimulator: false)
        let routine = try #require(record.routines.first)
        #expect(await model.send(.removeRoutine(routine.id), now: now))
        #expect(model.todayState == .empty)
        #expect(!model.history.allSatisfy { $0.hands.isEmpty })
        let reloaded = PostPresentation(storage: storage, now: now)
        await reloaded.load(now: now, seedSimulator: false)
        #expect(reloaded.history.first?.hands == record.handMarks)
        #expect(reloaded.history.first?.obligations.first?.routineName == routine.name)
    }
}
