import Foundation

/// The only persistence seam consumed by presentation; implementations are actor-isolated.
protocol HouseholdStorage: Sendable {
    func load() async throws -> HouseholdLoad
    func save(_ record: HouseholdRecord) async throws
    func resetAllData() async throws
    func flush() async throws
}

/// Recoveries are visible, actionable state rather than silent loss or a launch crash.
struct HouseholdLoad: Sendable {
    let record: HouseholdRecord
    let recovery: HouseholdRecovery?
}

enum HouseholdRecovery: String, Equatable, Sendable {
    case backup, defaults, empty

    var message: String {
        switch self {
        case .backup: "The household was recovered from its backup. Review your latest round, then save again."
        case .defaults: "The household was recovered from its local copy. Review your latest round, then save again."
        case .empty: "The household could not be read. The damaged data was kept. Retry storage or reset to start again."
        }
    }
}

enum HouseholdStorageError: Error, LocalizedError, Equatable, Sendable {
    case invalidRecord
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidRecord: "The household record is invalid. Retry loading your saved data."
        case let .unavailable(reason): "The household could not be saved or opened. \(reason) Retry before leaving."
        }
    }
}
