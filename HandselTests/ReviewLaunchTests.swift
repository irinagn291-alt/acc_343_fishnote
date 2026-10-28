import Foundation
import XCTest
@testable import Handsel

/// XCTest supplies the executed-test summary recognized by the delivery checker.
/// These remain parser/state tests and never host a View.
@MainActor
final class ReviewLaunchTests: XCTestCase {
    func testParsesCoverKeys() async {
        let keys = ["today", "log", "goals", "pets", "routines", "settings", "pet-edit", "routine-edit", "beckon"]
        for key in keys {
            XCTAssertEqual(ReviewLaunch.parse(arguments: ["Handsel", "-ReviewScreen", key]), key)
        }
    }

    func testMissingAndMalformedArgumentsAreIgnored() async {
        XCTAssertNil(ReviewLaunch.parse(arguments: []))
        XCTAssertNil(ReviewLaunch.parse(arguments: ["Handsel", "-ReviewScreen"]))
        XCTAssertNil(ReviewLaunch.parse(arguments: ["Handsel", "-ReviewScreen", "-OtherFlag"]))
        XCTAssertNil(ReviewLaunch.parse(arguments: ["Handsel", "-ReviewScreen", ""]))
        XCTAssertEqual(ReviewLaunch.screen, ReviewLaunch.parse(arguments: ProcessInfo.processInfo.arguments))
    }

    func testCoverKeysRepresentDistinctSheetsWithPersistentTodayRoot() async {
        XCTAssertNil(PostSheet(reviewKey: "today"))
        XCTAssertEqual(PostSheet(reviewKey: "log"), .history)
        XCTAssertEqual(PostSheet(reviewKey: "goals"), .beckonGuide)
        XCTAssertEqual(PostSheet(reviewKey: "settings"), .settings)
        let keys = ["log", "goals", "pets", "routines", "settings"]
        XCTAssertEqual(Set(keys.compactMap { PostSheet(reviewKey: $0)?.rawValue }).count, keys.count)
        XCTAssertNil(PostSheet(reviewKey: "unknown"))
    }

    func testTokenFeedbackIsTransientAndClamped() async {
        var token = Token()
        token.aim(at: PostFixture.firstID, progress: 2)
        XCTAssertEqual(token.progress, 1)
        token.aim(at: PostFixture.firstID, progress: .nan)
        XCTAssertEqual(token.progress, 0)
        token.release()
        XCTAssertEqual(token, Token())
    }
}
