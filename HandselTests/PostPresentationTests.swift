import Foundation
import Testing
@testable import Handsel

/// Actor fake injects save failure/cancellation at the storage seam; tests never host views.
actor PostTestStorage: HouseholdStorage {
    var record: HouseholdRecord
    var failure = false
    var loadFailure = false
    var cancellation = false
    var delay = false
    var saves = 0
    var recovery: HouseholdRecovery?

    init(_ record: HouseholdRecord = HouseholdRecord(), recovery: HouseholdRecovery? = nil) {
        self.record = record
        self.recovery = recovery
    }
    func setLoadFailure(_ value: Bool = true) { loadFailure = value }
    func setFailure(_ value: Bool) { failure = value }
    func setCancellation() { cancellation = true }
    func setDelay() { delay = true }
    func load() async throws -> HouseholdLoad {
        if loadFailure { throw HouseholdStorageError.unavailable("Storage cannot be opened.") }
        return HouseholdLoad(record: record, recovery: recovery)
    }
    func save(_ candidate: HouseholdRecord) async throws {
        if delay { try await Task.sleep(for: .milliseconds(30)) }
        if cancellation { throw CancellationError() }
        if failure { throw HouseholdStorageError.unavailable("Storage is full.") }
        record = candidate
        saves += 1
    }
    func resetAllData() async throws {
        if failure { throw HouseholdStorageError.unavailable("Storage is full.") }
        record = HouseholdRecord()
    }
    func flush() async throws { try Task.checkCancellation() }
}

@Suite("Post presentation")
@MainActor
struct PostPresentationTests {
    private func date(_ key: Int = PostFixture.day) throws -> Date {
        try #require(PostCalendar().date(for: key))
    }

    @Test func onlyDurableHandTriggersOneSuccessFeedback() async throws {
        let now = try date()
        let storage = PostTestStorage(try PostFixture.household())
        var successes = 0
        let model = PostPresentation(storage: storage, now: now, successFeedback: { successes += 1 })
        await model.load(now: now, seedSimulator: false)
        #expect(!model.canHand)
        #expect(await model.send(.beckon(petID: PostFixture.firstID), now: now))
        #expect(successes == 0)
        #expect(model.canHand)
        #expect(await model.hand(to: PostFixture.secondID, now: now))
        #expect(successes == 0)
        #expect(model.post.phase == .beckoned(petID: PostFixture.firstID))
        #expect(await model.hand(now: now))
        #expect(successes == 1)
        #expect(model.post.completedCount == 1)
        #expect(!(await model.hand(now: now)))
        #expect(successes == 1)
    }

    @Test func saveFailureKeepsOldHouseholdAndAllowsRetry() async throws {
        let now = try date()
        let record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: PostFixture.household(rounds: 1))
        let storage = PostTestStorage(record)
        var feedback = 0
        let model = PostPresentation(storage: storage, now: now, successFeedback: { feedback += 1 })
        await model.load(now: now, seedSimulator: false)
        await storage.setFailure(true)
        #expect(!(await model.hand(now: now)))
        #expect(model.household == record)
        #expect(feedback == 0)
        #expect(model.errorMessage?.contains("Retry") == true)
        await storage.setFailure(false)
        #expect(await model.hand(now: now))
        #expect(feedback == 1)
        #expect(model.post.phase == .shut)
        #expect(!(await model.hand(now: now)))
        #expect(model.errorMessage == "This day is complete. Undo the latest logged round to reopen it.")
        #expect(!(await model.send(.beckon(petID: PostFixture.firstID), now: now)))
        #expect(feedback == 1)
    }

    @Test func movingLoggedCareKeepsHistoryAndExplainsHowToContinue() async throws {
        let now = try date()
        let storage = PostTestStorage(try PostFixture.household())
        let model = PostPresentation(storage: storage, now: now)
        await model.load(now: now, seedSimulator: false)
        #expect(await model.send(.beckon(petID: PostFixture.firstID), now: now))
        #expect(await model.hand(now: now))
        let logged = model.household
        var round = try #require(logged.routines.first { $0.petID == PostFixture.firstID })
        round.petID = PostFixture.secondID
        #expect(!(await model.send(.saveRoutine(round), now: now)))
        #expect(model.errorMessage == "This round already has a log today. Add a new care round for the other pet.")
        #expect(model.household == logged)
        #expect(await storage.record == logged)
        // Follow the offered next step through the same command path as the editor.
        let newRound = Routine(petID: PostFixture.secondID, name: round.name)
        #expect(await model.send(.saveRoutine(newRound), now: now))
        #expect(model.errorMessage == nil)
        #expect(model.household.handMarks == logged.handMarks)
        #expect(model.post.remaining.contains { $0.routineID == newRound.id })
        #expect(await storage.record == model.household)
    }

    @Test func cancellationIsNotErrorUIOrSuccessFeedback() async throws {
        let now = try date()
        let record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: PostFixture.household())
        let storage = PostTestStorage(record)
        let model = PostPresentation(storage: storage, now: now)
        await model.load(now: now, seedSimulator: false)
        await storage.setCancellation()
        #expect(!(await model.hand(now: now)))
        #expect(model.errorMessage == nil)
        #expect(model.household == record)
        #expect(!model.isWorking)
    }

    @Test func rapidDoubleHandCannotCommitTwice() async throws {
        let now = try date()
        let record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: PostFixture.household())
        let storage = PostTestStorage(record)
        let model = PostPresentation(storage: storage, now: now)
        await model.load(now: now, seedSimulator: false)
        await storage.setDelay()
        async let first = model.hand(now: now)
        async let second = model.hand(now: now)
        let outcomes = await [first, second]
        #expect(outcomes.filter { $0 }.count == 1)
        #expect(model.post.completedCount == 1)
        #expect(await storage.saves == 1)
    }

    @Test func exposesEmptyPopulatedAndErrorStatesWithoutBuildingScreens() async throws {
        let now = try date()
        let storage = PostTestStorage()
        let model = PostPresentation(storage: storage, now: now)
        #expect(model.todayState == .loading)
        await model.load(now: now, seedSimulator: false)
        #expect(model.todayState == .empty)
        #expect(model.petsState == .empty)
        #expect(model.routinesState == .empty)
        let pet = Pet(name: "Hazel")
        #expect(await model.send(.savePet(pet), now: now))
        #expect(await model.send(.saveRoutine(Routine(petID: pet.id, name: "Water")), now: now))
        #expect(model.todayState == .populated)
        #expect(model.petsState == .populated)
        #expect(model.routinesState == .populated)
        #expect(!(await model.send(.savePet(Pet(name: "")), now: now)))
        #expect(model.errorMessage != nil)
        await model.resetAllData(now: now)
        #expect(model.todayState == .empty)
        #expect(!model.onboarding.isComplete)
    }

    @Test func initialLoadFailureShowsRetryableErrorInsteadOfLoadingForever() async throws {
        let now = try date()
        let storage = PostTestStorage()
        await storage.setLoadFailure()
        let model = PostPresentation(storage: storage, now: now)
        #expect(!model.shouldShowOnboarding)
        await model.load(now: now, seedSimulator: false)
        #expect(!model.isLoaded)
        #expect(!model.shouldShowOnboarding)
        if case let .error(message) = model.todayState {
            #expect(message.contains("Retry"))
        } else {
            Issue.record("Failed initial storage must be an error state")
        }
        #expect(model.petsState == model.todayState)
        #expect(model.routinesState == model.todayState)
        #expect(model.settingsState == model.todayState)
        await storage.setLoadFailure(false)
        await model.load(now: now, seedSimulator: false)
        #expect(model.errorMessage == nil)
        #expect(model.shouldShowOnboarding)
        #expect(await model.send(.completeOnboarding, now: now))
        #expect(!model.shouldShowOnboarding)
    }

    @Test func midnightRefreshOpensIdleDayWithoutRewritingYesterday() async throws {
        let now = try date()
        let record = try PostFixture.complete(PostFixture.household())
        let model = PostPresentation(storage: PostTestStorage(record), now: now)
        await model.load(now: now, seedSimulator: false)
        await model.refreshDay(now: try date(20261027))
        #expect(model.daykey == 20261027)
        #expect(model.post.phase == .idle)
        #expect(model.post.completedCount == 0)
        #expect(PostFold.fold(model.household, daykey: PostFixture.day).isComplete)
    }

    @Test func recoveryOfEmptyDataCannotOverwriteDamagedRecordsOrSeed() async throws {
        let now = try date()
        let storage = PostTestStorage(recovery: .empty)
        let model = PostPresentation(storage: storage, now: now)
        await model.load(now: now)
        #expect(model.recovery == .empty)
        #expect(model.household.pets.isEmpty)
        #expect(model.errorMessage != nil)
        #expect(!model.shouldShowOnboarding)
        #expect(!(await model.send(.savePet(Pet(name: "Hazel")), now: now)))
        #expect(await storage.saves == 0)
    }

    @Test(arguments: [false, true])
    func resetEscapesInitialLoadFailureAndUnrecoverableCorruption(corrupt: Bool) async throws {
        let now = try date()
        let storage = PostTestStorage(recovery: corrupt ? .empty : nil)
        await storage.setLoadFailure(!corrupt)
        let model = PostPresentation(storage: storage, now: now)
        await model.load(now: now, seedSimulator: false)
        #expect(!model.shouldShowOnboarding)
        model.sheet = .settings
        await storage.setFailure(true)
        await model.resetAllData(now: now)
        #expect(!model.shouldShowOnboarding)
        #expect(model.sheet == .settings)
        await storage.setFailure(false)
        await model.resetAllData(now: now)
        #expect(model.sheet == nil)
        #expect(model.errorMessage == nil)
        #expect(model.recovery == nil)
        #expect(model.shouldShowOnboarding)
        #expect(await model.send(.completeOnboarding, now: now))
        #expect(!model.shouldShowOnboarding)
    }

    @Test func obligationEditPublishesShutOnlyAfterDurableSave() async throws {
        let now = try date()
        var record = try PostFixture.household()
        record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: record)
        record = try PostFixture.applying(.hand(petID: PostFixture.firstID), to: record)
        let routine = try #require(record.routines.first { $0.petID == PostFixture.secondID })
        let storage = PostTestStorage(record)
        var feedback = 0
        let model = PostPresentation(storage: storage, now: now, successFeedback: { feedback += 1 })
        await model.load(now: now, seedSimulator: false)
        await storage.setFailure(true)
        #expect(!(await model.send(.removeRoutine(routine.id), now: now)))
        #expect(model.household == record)
        #expect(await storage.record == record)
        await storage.setFailure(false)
        #expect(await model.send(.removeRoutine(routine.id), now: now))
        #expect(model.post.phase == .shut)
        #expect(model.household.shutMarks.count == 1)
        #expect(await storage.record == model.household)
        #expect(feedback == 0)
        let reloaded = PostPresentation(storage: storage, now: now)
        await reloaded.load(now: now, seedSimulator: false)
        #expect(reloaded.post.phase == .shut)
        #expect(reloaded.household.shutMarks == model.household.shutMarks)
    }

    @Test func onboardingSkipAndRestartUseDurableDefaults() async throws {
        let now = try date()
        let model = PostPresentation(storage: PostTestStorage(), now: now)
        await model.load(now: now, seedSimulator: false)
        #expect(model.onboarding.pages.count == 3)
        #expect(await model.send(.completeOnboarding, now: now))
        #expect(model.onboarding.isComplete)
        #expect(await model.send(.restartOnboarding, now: now))
        #expect(!model.onboarding.isComplete)
    }

    @Test func simulatorSeedStartsBeckonedAndIsIdempotent() throws {
        #if targetEnvironment(simulator)
        let now = try date()
        let record = try HouseholdSeed.prepare(HouseholdRecord(), now: now, calendar: PostCalendar())
        #expect(record.pets.count >= 3)
        #expect(record.routines.count >= 5)
        #expect(record.onboardingComplete)
        #expect(record.demoVersion == "hns.demo.v1")
        #expect(PostFold.fold(record, daykey: PostFixture.day).canHand)
        #expect(PostCalendar().streak(in: record, through: now) == 3)
        #expect(try HouseholdSeed.prepare(record, now: now, calendar: PostCalendar()) == record)
        #else
        #expect(try HouseholdSeed.prepare(HouseholdRecord(), now: date(), calendar: PostCalendar()) == HouseholdRecord())
        #endif
    }
}
