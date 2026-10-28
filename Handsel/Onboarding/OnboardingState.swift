import Foundation

/// Three explanatory pages share the same completion command, including Skip, before launch routing.
struct OnboardingState: Equatable, Sendable {
    let isComplete: Bool
    let pages = [
        "Keep each pet's care rounds together on Today.",
        "Beckon a pet, then Hand to log its next care round.",
        "Finish every owed round to shut the day. Your records stay on this device."
    ]
}
