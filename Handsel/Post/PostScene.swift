import SpriteKit
import SwiftUI

/// The entire care post, including each animal and the current beckon, is one SpriteKit surface.
/// Native overlays and drawing share measured bounds; SpriteKit never owns care state.
struct PostSceneInput: Equatable {
    let size: CGSize
    let post: Post
    let pets: [Pet]
    let targets: PostDropTargets
    let portraits: [UUID: CGRect]
    let stacked: Bool
    let reduceMotion: Bool
}

@MainActor
final class PostScene: SKScene {
    private var input: PostSceneInput?
    private var tokenNode: SKNode?
    private var seats: [UUID: SKShapeNode] = [:]
    private(set) var beckonedPetID: UUID?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(DesignTokens.surface).withAlphaComponent(0)
    }

    required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }

    func show(_ input: PostSceneInput) {
        self.input = input
        size = input.size
        beckonedPetID = input.post.beckonedPetID
        removeAllChildren()
        seats.removeAll()
        tokenNode = nil
        guard !input.targets.tokenBounds.isEmpty else { return }
        drawPost(input)
        for pet in input.pets {
            guard let portrait = input.portraits[pet.id], !portrait.isEmpty else { continue }
            drawPet(pet, in: portrait, selected: pet.id == beckonedPetID)
        }
        drawToken(in: input.targets.tokenBounds, ready: input.post.canHand)
    }

    func aim(from start: CGPoint?, at location: CGPoint?) {
        guard let input else { return }
        let target = location.flatMap { input.targets.pet(at: $0) }
        for (id, seat) in seats {
            seat.lineWidth = id == target ? 3 : 1
            seat.fillColor = UIColor(DesignTokens.accent.opacity(id == beckonedPetID ? 0.20 : 0.04))
            seat.strokeColor = UIColor(id == target ? DesignTokens.ink : DesignTokens.muted.opacity(0.4))
        }
        let rest = CGPoint(x: input.targets.tokenBounds.midX, y: input.targets.tokenBounds.midY)
        if let start, let location, !input.reduceMotion {
            tokenNode?.position = point(CGPoint(x: rest.x + location.x - start.x, y: rest.y + location.y - start.y))
        } else {
            tokenNode?.position = point(rest)
        }
        tokenNode?.alpha = target == nil && location != nil ? 0.65 : 1
    }

    private func point(_ native: CGPoint) -> CGPoint { PostDropTargets.scenePoint(native, height: size.height) }

    private func drawPost(_ input: PostSceneInput) {
        let token = input.targets.tokenBounds
        for pet in input.pets {
            guard let portrait = input.portraits[pet.id] else { continue }
            let path = CGMutablePath()
            if input.stacked {
                let railX = Spacing.xs
                path.move(to: point(CGPoint(x: token.minX, y: token.midY)))
                path.addLine(to: point(CGPoint(x: railX, y: token.midY)))
                path.addLine(to: point(CGPoint(x: railX, y: portrait.midY)))
                path.addLine(to: point(CGPoint(x: portrait.midX, y: portrait.midY)))
            } else {
                let railX = (token.maxX + portrait.minX) / 2
                path.move(to: point(CGPoint(x: token.maxX, y: token.midY)))
                path.addLine(to: point(CGPoint(x: railX, y: token.midY)))
                path.addLine(to: point(CGPoint(x: railX, y: portrait.midY)))
                path.addLine(to: point(CGPoint(x: portrait.midX, y: portrait.midY)))
            }
            let rail = SKShapeNode(path: path)
            rail.name = "rail.\(pet.id)"
            rail.strokeColor = UIColor(pet.id == beckonedPetID ? DesignTokens.accent : DesignTokens.muted.opacity(0.25))
            rail.lineWidth = pet.id == beckonedPetID ? 2 : 1
            addChild(rail)
        }
    }

    private func drawPet(_ pet: Pet, in portrait: CGRect, selected: Bool) {
        let node = SKNode()
        node.name = "pet.\(pet.id)"
        node.position = point(CGPoint(x: portrait.midX, y: portrait.midY))
        let scale = min(portrait.width / 88, portrait.height / 88, 1.6)
        node.setScale(scale)
        let seat = shape(width: 80, height: 76, radius: PostRadius.surface,
                         fill: DesignTokens.accent.opacity(selected ? 0.20 : 0.04), stroke: DesignTokens.muted.opacity(0.4))
        seat.name = selected ? "beckoned" : "waiting"
        node.addChild(seat)
        seats[pet.id] = seat
        let body = shape(width: 36, height: 36, radius: PostRadius.surface, fill: DesignTokens.surface, stroke: DesignTokens.ink)
        body.position.y = -16
        node.addChild(body)
        for side: CGFloat in [-1, 1] {
            let ear = shape(width: 16, height: 28, radius: PostRadius.control, fill: DesignTokens.surface, stroke: DesignTokens.ink)
            ear.position = CGPoint(x: side * 20, y: 20)
            ear.zRotation = side * .pi / 10
            node.addChild(ear)
        }
        let head = shape(width: 52, height: 40, radius: PostRadius.surface, fill: DesignTokens.surface, stroke: DesignTokens.ink)
        head.position.y = 8
        node.addChild(head)
        for side: CGFloat in [-1, 1] {
            let eye = shape(width: 4, height: 8, radius: PostRadius.control, fill: DesignTokens.ink, stroke: DesignTokens.ink)
            eye.position = CGPoint(x: side * 12, y: 12)
            node.addChild(eye)
        }
        let nose = shape(width: 8, height: 4, radius: PostRadius.control, fill: DesignTokens.ink, stroke: DesignTokens.ink)
        nose.position.y = 2
        node.addChild(nose)
        addChild(node)
    }

    private func drawToken(in rect: CGRect, ready: Bool) {
        let token = SKNode()
        token.name = "care-token"
        token.position = point(CGPoint(x: rect.midX, y: rect.midY))
        let base = shape(width: rect.width, height: rect.height * 0.76, radius: PostRadius.surface,
                         fill: ready ? DesignTokens.accent : DesignTokens.surface, stroke: DesignTokens.ink)
        base.zRotation = .pi / 16
        token.addChild(base)
        let face = shape(width: rect.width * 0.82, height: rect.height * 0.82, radius: PostRadius.surface,
                         fill: DesignTokens.surface, stroke: DesignTokens.ink)
        token.addChild(face)
        let inset = shape(width: rect.width * 0.48, height: rect.height * 0.48, radius: PostRadius.control,
                          fill: DesignTokens.accent.opacity(ready ? 0.5 : 0.1), stroke: DesignTokens.ink)
        token.addChild(inset)
        token.zPosition = 1
        addChild(token)
        tokenNode = token
    }

    private func shape(width: CGFloat, height: CGFloat, radius: CGFloat, fill: Color, stroke: Color) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: radius)
        node.fillColor = UIColor(fill)
        node.strokeColor = UIColor(stroke)
        node.lineWidth = 2
        return node
    }
}
