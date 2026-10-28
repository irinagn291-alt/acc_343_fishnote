import Foundation
import CoreGraphics
import Testing
@testable import Handsel

@Suite("Token drop destinations")
@MainActor
struct PostDropTests {
    private func targets(stacked: Bool) -> PostDropTargets {
        PostDropTargets(
            tokenBounds: CGRect(x: 24, y: 24, width: 120, height: 120),
            petBounds: [
                PostFixture.firstID: CGRect(x: stacked ? 24 : 224, y: stacked ? 224 : 24, width: 120, height: 120),
                PostFixture.secondID: CGRect(x: stacked ? 24 : 224, y: stacked ? 424 : 224, width: 120, height: 120)
            ])
    }

    @Test(arguments: [false, true])
    func onlyTheActualReleaseTargetReceivesTheToken(stacked: Bool) async throws {
        let now = try #require(PostCalendar().date(for: PostFixture.day))
        let record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: PostFixture.household())
        let storage = PostTestStorage(record)
        var haptics = 0
        let model = PostPresentation(storage: storage, now: now, successFeedback: { haptics += 1 })
        await model.load(now: now, seedSimulator: false)
        let frames = targets(stacked: stacked)
        let start = CGPoint(x: frames.tokenBounds.midX, y: frames.tokenBounds.midY)
        // A long horizontal translation over empty space must not log the selected animal.
        #expect(!(await model.dropToken(from: start, at: CGPoint(x: 600, y: 80), targets: frames, now: now)))
        #expect(model.household == record)
        #expect(await storage.saves == 0)
        let other = try #require(frames.petBounds[PostFixture.secondID])
        #expect(await model.dropToken(from: start, at: CGPoint(x: other.midX, y: other.midY), targets: frames, now: now))
        #expect(model.lastEffect == .missed)
        #expect(model.household.handMarks.isEmpty)
        #expect(model.household.missMarks.last?.petID == PostFixture.secondID)
        #expect(model.post.beckonedPetID == PostFixture.firstID)
        #expect(haptics == 0)
        let selected = try #require(frames.petBounds[PostFixture.firstID])
        #expect(await model.dropToken(from: start, at: CGPoint(x: selected.midX, y: selected.midY), targets: frames, now: now))
        #expect(model.post.completedCount == 1)
        #expect(model.household.handMarks.last?.petID == PostFixture.firstID)
        #expect(model.token == Token())
        #expect(haptics == 1)
        #expect(await storage.saves == 2)
    }

    @Test func wrongOriginOutsideEdgesAndOverlappingTargetsCancel() {
        var frames = targets(stacked: false)
        let start = CGPoint(x: 84, y: 84)
        #expect(frames.target(from: CGPoint(x: 180, y: 180), to: CGPoint(x: 250, y: 50)) == nil)
        #expect(frames.target(from: start, to: CGPoint(x: 223, y: 50)) == nil)
        #expect(frames.target(from: start, to: CGPoint(x: 345, y: 50)) == nil)
        frames.petBounds[PostFixture.secondID] = frames.petBounds[PostFixture.firstID]
        #expect(frames.target(from: start, to: CGPoint(x: 250, y: 50)) == nil)
    }

    @Test func reflowUsesTheNewBoundsAndSpriteCoordinatesMatchNativeCoordinates() throws {
        let portrait = targets(stacked: false)
        let stacked = targets(stacked: true)
        let start = CGPoint(x: 84, y: 84)
        #expect(portrait.target(from: start, to: CGPoint(x: 284, y: 84)) == PostFixture.firstID)
        #expect(stacked.target(from: start, to: CGPoint(x: 284, y: 84)) == nil)
        #expect(stacked.target(from: start, to: CGPoint(x: 84, y: 284)) == PostFixture.firstID)
        for height: CGFloat in [390, 844, 1024] {
            let point = CGPoint(x: 100, y: 224)
            let scene = PostDropTargets.scenePoint(point, height: height)
            #expect(scene == CGPoint(x: 100, y: height - 224))
            #expect(PostDropTargets.scenePoint(scene, height: height) == point)
        }
    }
}
