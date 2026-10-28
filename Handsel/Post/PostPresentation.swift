import Foundation
import Observation

/// Main-actor state between data and the future post/sheets. Publishes only committed transactions.
/// Views own async call lifetimes; this type starts no unstructured tasks or timers.
@MainActor @Observable
final class PostPresentation {
    private let storage: any HouseholdStorage
    private let calendar: PostCalendar
    private let successFeedback: @MainActor () -> Void
    private var didReadReviewLaunch = false
    private(set) var household = HouseholdRecord()
    private(set) var daykey: Int
    private(set) var isLoaded = false
    private(set) var isWorking = false
    private(set) var errorMessage: String?
    private(set) var recovery: HouseholdRecovery?
    private(set) var lastEffect: PostEffect = .none
    var reviewDiagnostic: String?
    var sheet: PostSheet?
    var token = Token()

    init(storage: any HouseholdStorage, calendar: PostCalendar = PostCalendar(), now: Date = .now,
         successFeedback: @escaping @MainActor () -> Void = {}) {
        self.storage = storage
        self.calendar = calendar
        self.daykey = calendar.daykey(for: now)
        self.successFeedback = successFeedback
    }

    var post: Post { PostFold.fold(household, daykey: daykey) }
    var canHand: Bool { isLoaded && !isWorking && post.canHand }
    var onboarding: OnboardingState { OnboardingState(isComplete: household.onboardingComplete) }
    var shouldShowOnboarding: Bool { isLoaded && recovery != .empty && !onboarding.isComplete }
    var todayState: PostContentState {
        if let errorMessage { return .error(errorMessage) }
        if !isLoaded { return .loading }
        return post.owedObligations.isEmpty ? .empty : .populated
    }
    var petsState: PostContentState { contentState(isEmpty: household.pets.isEmpty) }
    var routinesState: PostContentState { contentState(isEmpty: household.routines.isEmpty) }
    var settingsState: PostContentState { contentState(isEmpty: false) }
    var streak: Int {
        guard let date = calendar.date(for: daykey) else { return 0 }
        return calendar.streak(in: household, through: date)
    }
    var history: [Post] { household.days.map { PostFold.fold(household, daykey: $0.daykey) }.sorted { $0.daykey > $1.daykey } }

    func load(now: Date = .now, seedSimulator: Bool = true) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let loaded = try await storage.load()
            try Task.checkCancellation()
            let seeded = seedSimulator && loaded.recovery == nil
                ? try HouseholdSeed.prepare(loaded.record, now: now, calendar: calendar) : loaded.record
            let key = calendar.daykey(for: now)
            let prepared = try PostFold.apply(.openDay, to: seeded, daykey: key, now: now).record
            if loaded.recovery != .empty, prepared != loaded.record { try await storage.save(prepared) }
            household = loaded.recovery == .empty ? loaded.record : prepared
            daykey = key
            recovery = loaded.recovery
            errorMessage = loaded.recovery?.message
            isLoaded = true
            readReviewLaunchAfterOnboarding()
        } catch is CancellationError {
            // Cancellation ends this attempt without presenting an error or replacing saved state.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func send(_ action: PostAction, now: Date = .now) async -> Bool {
        guard isLoaded, !isWorking, recovery != .empty else { return false }
        isWorking = true
        lastEffect = .none
        defer { isWorking = false }
        do {
            let key = calendar.daykey(for: now)
            let transition = try PostFold.apply(action, to: household, daykey: key, now: now)
            if transition.record != household { try await storage.save(transition.record) }
            household = transition.record
            daykey = key
            recovery = nil
            errorMessage = transition.refusal?.localizedDescription
            lastEffect = transition.effect
            if case .handed = transition.effect { successFeedback() }
            readReviewLaunchAfterOnboarding()
            return transition.refusal == nil
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func hand(to petID: UUID? = nil, now: Date = .now) async -> Bool {
        guard let target = petID ?? post.beckonedPetID else {
            // Route Idle through the fold as well; no successful-care feedback is produced.
            return await send(.hand(petID: UUID()), now: now)
        }
        return await send(.hand(petID: target), now: now)
    }

    // Hit testing resolves the actual release target before entering the existing Hand command.
    func dropToken(from start: CGPoint, at release: CGPoint, targets: PostDropTargets, now: Date = .now) async -> Bool {
        defer { token.release() }
        guard canHand, let petID = targets.target(from: start, to: release) else { return false }
        return await hand(to: petID, now: now)
    }

    func refreshDay(now: Date = .now) async {
        if calendar.daykey(for: now) != daykey { _ = await send(.openDay, now: now) }
    }

    func flush() async {
        do { try await storage.flush() }
        catch is CancellationError { return }
        catch { errorMessage = error.localizedDescription }
    }

    func resetAllData(now: Date = .now) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await storage.resetAllData()
            var empty = HouseholdRecord()
            empty.demoVersion = household.demoVersion
            household = empty
            isLoaded = true
            daykey = calendar.daykey(for: now)
            recovery = nil
            errorMessage = nil
            lastEffect = .none
            sheet = nil
            token.release()
        } catch is CancellationError { return }
        catch { errorMessage = error.localizedDescription }
    }

    private func contentState(isEmpty: Bool) -> PostContentState {
        if let errorMessage { return .error(errorMessage) }
        if !isLoaded { return .loading }
        return isEmpty ? .empty : .populated
    }

    private func readReviewLaunchAfterOnboarding() {
        guard household.onboardingComplete, !didReadReviewLaunch else { return }
        didReadReviewLaunch = true
        guard let key = ReviewLaunch.screen else { return }
        if key == "today" { sheet = nil; return }
        if let destination = PostSheet(reviewKey: key) {
            sheet = destination
        } else {
            #if targetEnvironment(simulator)
            reviewDiagnostic = "Unknown -ReviewScreen key: \(key)"
            #endif
        }
    }
}

/// Presentation loading, empty, populated and retryable error states for all future surfaces.
enum PostContentState: Equatable, Sendable {
    case loading, empty, populated, error(String)
}

/// Sheet destinations preserve the Today root. Launch keys are not tabs.
enum PostSheet: String, Identifiable, Sendable {
    case pets, routines, settings, history, petEditor, routineEditor, beckonGuide
    var id: String { rawValue }

    init?(reviewKey: String) {
        switch reviewKey {
        case "goals": self = .beckonGuide
        case "pets": self = .pets
        case "routines": self = .routines
        case "log", "history": self = .history
        case "settings": self = .settings
        case "pet-edit": self = .petEditor
        case "routine-edit": self = .routineEditor
        case "beckon": self = .beckonGuide
        default: return nil
        }
    }
}
