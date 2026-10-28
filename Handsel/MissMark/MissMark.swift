import Foundation

/// An attempted hand to a different Pet. It neither fulfils care nor consumes the beckon.
struct MissMark: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let petID: UUID
    let beckonedPetID: UUID
    let daykey: Int
    let sequence: Int
    let createdAt: Date
}
