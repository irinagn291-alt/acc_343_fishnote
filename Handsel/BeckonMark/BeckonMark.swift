import Foundation

/// Seats one Pet at the post. Sequence, rather than wall-clock time, orders the fold.
struct BeckonMark: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let petID: UUID
    let daykey: Int
    let sequence: Int
    let createdAt: Date
}
