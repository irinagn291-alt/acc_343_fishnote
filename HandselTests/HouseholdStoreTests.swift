import Foundation
import Testing
@testable import Handsel

/// Isolated disk and defaults namespaces exercise real persistence without touching a user's household.
struct StoreFixture {
    let directory = FileManager.default.temporaryDirectory.appending(path: "HandselTests-\(UUID().uuidString)")
    let suite = "HandselTests.\(UUID().uuidString)"
    var file: URL { directory.appending(path: "hns.household.v1.json") }
    var backup: URL { file.appendingPathExtension("backup") }
    func store() -> HouseholdStore { HouseholdStore(directory: directory, suiteName: suite) }
    func clean() {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}

@Suite("Household persistence")
struct HouseholdStoreTests {
    @Test func roundTripAcrossNewStoreRetainsFinalHandShutAndSnapshots() async throws {
        let fixture = StoreFixture()
        defer { fixture.clean() }
        let record = try PostFixture.complete(PostFixture.household())
        let store = fixture.store()
        _ = try await store.load()
        try await store.save(record)
        let reloaded = try await fixture.store().load()
        #expect(reloaded.record == record)
        #expect(reloaded.recovery == nil)
        #expect(PostFold.fold(reloaded.record, daykey: PostFixture.day).phase == .shut)
        #expect(reloaded.record.shutMarks.first?.handMarkID == reloaded.record.handMarks.last?.id)
        let data = try #require(UserDefaults(suiteName: fixture.suite)?.data(forKey: HouseholdStore.householdKey))
        #expect(try JSONDecoder().decode(HouseholdRecord.self, from: data) == record)
    }

    @Test func malformedPrimaryRecoversPreviousGoodBackupAndPreservesBytes() async throws {
        let fixture = StoreFixture()
        defer { fixture.clean() }
        let first = try PostFixture.household()
        let second = try PostFixture.complete(first)
        let store = fixture.store()
        _ = try await store.load()
        try await store.save(first)
        try await store.save(second)
        let damaged = Data("not JSON".utf8)
        try damaged.write(to: fixture.file, options: .atomic)
        let recovered = try await fixture.store().load()
        #expect(recovered.record == first)
        #expect(recovered.recovery == .backup)
        let files = try FileManager.default.contentsOfDirectory(at: fixture.directory, includingPropertiesForKeys: nil)
        let preserved = try #require(files.first { $0.lastPathComponent.contains("corrupt.") })
        #expect(try Data(contentsOf: preserved) == damaged)
        let recoveredStore = fixture.store()
        _ = try await recoveredStore.load()
        try await recoveredStore.save(first)
        #expect(try JSONDecoder().decode(HouseholdRecord.self, from: Data(contentsOf: fixture.backup)) == first)
    }

    @Test func bothDamagedFilesFallBackToDefaults() async throws {
        let fixture = StoreFixture()
        defer { fixture.clean() }
        let record = try PostFixture.household()
        try await fixture.store().save(record)
        try Data("broken".utf8).write(to: fixture.file, options: .atomic)
        try Data("broken too".utf8).write(to: fixture.backup, options: .atomic)
        let loaded = try await fixture.store().load()
        #expect(loaded.record == record)
        #expect(loaded.recovery == .defaults)
    }

    @Test func allCorruptOrUnsupportedDataStartsEmptyWithRecoveryNotice() async throws {
        let fixture = StoreFixture()
        defer { fixture.clean() }
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        let unsupported = Data("{\"schemaVersion\":999}".utf8)
        try unsupported.write(to: fixture.file, options: .atomic)
        UserDefaults(suiteName: fixture.suite)?.set(unsupported, forKey: HouseholdStore.householdKey)
        let store = fixture.store()
        let loaded = try await store.load()
        #expect(loaded.record.pets.isEmpty)
        #expect(loaded.recovery == .empty)
        // Retry cannot silently reclassify damaged data as a clean install eligible for demo seeding.
        #expect(try await store.load().recovery == .empty)
        #expect(try Data(contentsOf: fixture.file) == unsupported)
    }

    @Test func resetSupersedesBothPrimaryAndBackup() async throws {
        let fixture = StoreFixture()
        defer { fixture.clean() }
        let store = fixture.store()
        try await store.save(PostFixture.complete(PostFixture.household()))
        try await store.resetAllData()
        let reloaded = try await fixture.store().load()
        #expect(reloaded.record == HouseholdRecord())
        #expect(try JSONDecoder().decode(HouseholdRecord.self, from: Data(contentsOf: fixture.backup)) == HouseholdRecord())
    }

    @Test func failureIsActionableAndDoesNotOverwriteDurableRecord() async throws {
        let fixture = StoreFixture()
        defer { fixture.clean() }
        let first = try PostFixture.household()
        let store = fixture.store()
        try await store.save(first)
        // A directory in the backup's place forces the transaction to fail before primary replacement.
        try FileManager.default.createDirectory(at: fixture.backup, withIntermediateDirectories: true)
        do {
            try await store.save(PostFixture.complete(first))
            Issue.record("Expected a typed storage failure")
        } catch let error as HouseholdStorageError {
            #expect(error.localizedDescription.contains("Retry"))
        }
        let loaded = try await fixture.store().load()
        #expect(loaded.record == first)
    }

    @Test func cancelledSaveDoesNotWrite() async throws {
        let fixture = StoreFixture()
        defer { fixture.clean() }
        let store = fixture.store()
        let record = try PostFixture.household()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await store.save(record)
        }
        do {
            try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            #expect(!FileManager.default.fileExists(atPath: fixture.file.path))
        }
    }

    @Test func semanticCorruptionIsRejectedWithoutDictionaryTrap() throws {
        var record = try PostFixture.household()
        record.pets.append(record.pets[0])
        let data = try JSONEncoder().encode(record)
        #expect(throws: HouseholdStorageError.invalidRecord) {
            try JSONDecoder().decode(HouseholdRecord.self, from: data)
        }
    }
}
