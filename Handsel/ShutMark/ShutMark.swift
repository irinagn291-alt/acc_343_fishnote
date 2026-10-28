import Foundation

/// Closes a complete day in the same transaction as its final HandMark.
struct ShutMark: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let handMarkID: UUID
    let daykey: Int
    let sequence: Int
    let createdAt: Date
}
