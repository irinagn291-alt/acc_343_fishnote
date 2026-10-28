import Foundation

/// Owns off-main IO, a validated source of truth, and atomic file commits mirrored to UserDefaults.
/// An awaited save is durable; failed writes never replace the previously committed household.
actor HouseholdStore: HouseholdStorage {
    static let householdKey = "hns.household.v1"
    static let demoKey = "hns.demo.v1"
    private let directory: URL
    private let suiteName: String?
    private var committed: HouseholdRecord?

    init(directory: URL? = nil, suiteName: String? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory
            .appending(path: "Fishnote", directoryHint: .isDirectory)
        self.suiteName = suiteName
    }

    private var file: URL { directory.appending(path: "hns.household.v1.json") }
    private var backup: URL { file.appendingPathExtension("backup") }
    private var defaults: UserDefaults { suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard }

    func load() async throws -> HouseholdLoad {
        try Task.checkCancellation()
        do {
            let manager = FileManager.default
            var damaged = false
            for (url, recovery) in [(file, HouseholdRecovery.defaults), (backup, HouseholdRecovery.backup)] {
                guard manager.fileExists(atPath: url.path) else { continue }
                let data = try Data(contentsOf: url)
                do {
                    let record = try JSONDecoder().decode(HouseholdRecord.self, from: data)
                    committed = record
                    return HouseholdLoad(record: record, recovery: url == file ? nil : recovery)
                } catch {
                    // Keep every corrupt or unsupported document intact for recovery outside the app.
                    damaged = true
                    let preserved = url.appendingPathExtension("corrupt.\(UUID().uuidString)")
                    try data.write(to: preserved, options: .atomic)
                }
            }
            if let data = defaults.data(forKey: Self.householdKey) {
                do {
                    let record = try JSONDecoder().decode(HouseholdRecord.self, from: data)
                    committed = record
                    return HouseholdLoad(record: record, recovery: damaged ? .defaults : nil)
                } catch {
                    damaged = true
                    defaults.set(data, forKey: "\(Self.householdKey).corrupt.\(UUID().uuidString)")
                }
            }
            let empty = HouseholdRecord()
            committed = empty
            return HouseholdLoad(record: empty, recovery: damaged ? .empty : nil)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw HouseholdStorageError.unavailable(error.localizedDescription)
        }
    }

    func save(_ record: HouseholdRecord) async throws {
        try Task.checkCancellation()
        do {
            try record.validate()
            let data = try JSONEncoder().encode(record)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // The backup is always a decoded, known-good record, never the potentially damaged file.
            if let committed {
                try JSONEncoder().encode(committed).write(to: backup, options: .atomic)
            }
            try Task.checkCancellation()
            try data.write(to: file, options: .atomic)
            defaults.set(data, forKey: Self.householdKey)
            defaults.set(record.demoVersion == Self.demoKey, forKey: Self.demoKey)
            committed = record
            // No cancellation check after the atomic commit: callers must publish a successful write.
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HouseholdStorageError {
            throw error
        } catch {
            throw HouseholdStorageError.unavailable(error.localizedDescription)
        }
    }

    func resetAllData() async throws {
        try Task.checkCancellation()
        var empty = HouseholdRecord()
        empty.demoVersion = committed?.demoVersion
        do {
            let data = try JSONEncoder().encode(empty)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Erase the recovery copy first. Until the primary commit succeeds, the old primary is valid.
            try data.write(to: backup, options: .atomic)
            try Task.checkCancellation()
            try data.write(to: file, options: .atomic)
            defaults.set(data, forKey: Self.householdKey)
            committed = empty
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw HouseholdStorageError.unavailable(error.localizedDescription)
        }
    }

    func flush() async throws {
        // Every edit is committed eagerly. There is no debounce queue to lose on force-quit.
        try Task.checkCancellation()
    }
}
