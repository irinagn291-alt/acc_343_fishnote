import Foundation

/// The persisted care log. One mark fulfils exactly one Pet's Routine on one day.
struct HandMark: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let petID: UUID
    let routineID: UUID
    let daykey: Int
    let sequence: Int
    let createdAt: Date
}
