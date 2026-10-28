import Foundation

/// Reopens the latest logged round still owed today. Archived care is historical and is retained.
enum UndoLatestHand {
    static func apply(to original: HouseholdRecord, daykey: Int, now: Date) throws -> HouseholdRecord {
        guard let latest = PostFold.fold(original, daykey: daykey).latestUndoableHand else {
            throw PostRefusal.noHand
        }
        var record = original
        record.handMarks.removeAll { $0.id == latest.id }
        record.shutMarks.removeAll { $0.daykey == daykey }
        record.beckonMarks.append(BeckonMark(id: UUID(), petID: latest.petID, daykey: daykey,
                                           sequence: record.nextSequence, createdAt: now))
        return record
    }
}
