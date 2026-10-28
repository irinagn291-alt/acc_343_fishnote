#if os(iOS)
import Foundation
import SpriteKit
import Testing
@testable import Handsel

@Suite("Live care post scene")
@MainActor
struct PostSceneTests {
    @Test func fullSceneContainsPetsAndReflectsTheFoldedBeckon() throws {
        var record = try PostFixture.household()
        record = try PostFixture.applying(.beckon(petID: PostFixture.firstID), to: record)
        let size = CGSize(width: 700, height: 900)
        let targets = PostDropTargets(tokenBounds: CGRect(x: 40, y: 300, width: 240, height: 240),
                                      petBounds: [PostFixture.firstID: CGRect(x: 440, y: 40, width: 200, height: 300),
                                                  PostFixture.secondID: CGRect(x: 440, y: 380, width: 200, height: 300)])
        let portraits = [PostFixture.firstID: CGRect(x: 460, y: 60, width: 160, height: 100),
                         PostFixture.secondID: CGRect(x: 460, y: 400, width: 160, height: 100)]
        let scene = PostScene(size: .zero)
        func show(reduceMotion: Bool = false) {
            scene.show(PostSceneInput(size: size, post: PostFold.fold(record, daykey: PostFixture.day),
                                      pets: record.pets, targets: targets, portraits: portraits,
                                      stacked: false, reduceMotion: reduceMotion))
        }
        show()
        #expect(scene.size == size)
        #expect(scene.backgroundColor.cgColor.alpha == 0)
        #expect(scene.beckonedPetID == PostFixture.firstID)
        for pet in record.pets {
            let node = try #require(scene.children.first { $0.name == "pet.\(pet.id)" })
            let portrait = try #require(portraits[pet.id])
            #expect(node.position == PostDropTargets.scenePoint(CGPoint(x: portrait.midX, y: portrait.midY), height: size.height))
            #expect(node.children.contains { $0.name == (pet.id == PostFixture.firstID ? "beckoned" : "waiting") })
        }
        let token = try #require(scene.children.first { $0.name == "care-token" })
        let rest = token.position
        scene.aim(from: CGPoint(x: 160, y: 420), at: CGPoint(x: 500, y: 100))
        #expect(token.position != rest)
        show(reduceMotion: true)
        let stillToken = try #require(scene.children.first { $0.name == "care-token" })
        scene.aim(from: CGPoint(x: 160, y: 420), at: CGPoint(x: 500, y: 100))
        #expect(stillToken.position == rest)
        record = try PostFixture.applying(.hand(petID: PostFixture.firstID), to: record)
        record = try PostFixture.applying(.beckon(petID: PostFixture.secondID), to: record)
        show()
        #expect(scene.beckonedPetID == PostFixture.secondID)
        #expect(scene.children.first { $0.name == "pet.\(PostFixture.secondID)" }?.children.contains { $0.name == "beckoned" } == true)
    }
}
#endif
