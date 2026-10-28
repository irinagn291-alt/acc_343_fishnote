import Foundation

/// Records a visit to an empty household, without treating an empty set of chores as complete.
struct Bare: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let daykey: Int
    let createdAt: Date
}
