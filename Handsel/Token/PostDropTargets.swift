import Foundation
import CoreGraphics

/// Measured native bounds in the post's top-left coordinate space, shared with SpriteKit.
/// Resolving an empty or ambiguous drop never falls back to the beckoned animal.
struct PostDropTargets: Equatable, Sendable {
    var tokenBounds: CGRect = .zero
    var petBounds: [UUID: CGRect] = [:]

    func pet(at point: CGPoint) -> UUID? {
        let matches = petBounds.filter { $0.value.contains(point) }
        return matches.count == 1 ? matches.first?.key : nil
    }

    func target(from start: CGPoint, to release: CGPoint) -> UUID? {
        guard !tokenBounds.isEmpty, tokenBounds.contains(start) else { return nil }
        return pet(at: release)
    }

    func progress(from start: CGPoint, to location: CGPoint, beckonedPetID: UUID?) -> Double {
        guard let beckonedPetID, let target = petBounds[beckonedPetID] else { return 0 }
        let distance = hypot(target.midX - start.x, target.midY - start.y)
        guard distance > 0 else { return 0 }
        return min(hypot(location.x - start.x, location.y - start.y) / distance, 1)
    }

    static func tokenBounds(in slot: CGRect) -> CGRect {
        let side = min(slot.width * 0.72, slot.height * 0.72, 240)
        return CGRect(x: slot.midX - side / 2, y: slot.midY - side / 2, width: side, height: side)
    }

    static func scenePoint(_ point: CGPoint, height: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: height - point.y)
    }
}
