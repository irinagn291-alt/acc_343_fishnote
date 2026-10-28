import Foundation

/// A household member with stable identity. Historical obligations retain its name after edits.
struct Pet: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var isActive: Bool

    init(id: UUID = UUID(), name: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}
