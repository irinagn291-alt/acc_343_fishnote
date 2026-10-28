import Foundation

/// Transient drag feedback. Both drop and native Hand call PostPresentation.hand, never write marks.
struct Token: Equatable, Sendable {
    var targetPetID: UUID?
    var progress: Double = 0

    mutating func aim(at petID: UUID?, progress: Double) {
        targetPetID = petID
        self.progress = progress.isFinite ? min(max(progress, 0), 1) : 0
    }

    mutating func release() { self = Token() }
}
