import SpriteKit
import SwiftUI

/// Native controls supply accessible labels and measured targets over one full-height SpriteView.
/// Both the scene and the drop resolver use this exact coordinate space after every reflow.
private struct PostBoardMeasurements: Equatable, Sendable {
    var tokenSlot: CGRect?
    var pets: [UUID: CGRect] = [:]
    var portraits: [UUID: CGRect] = [:]

    var targets: PostDropTargets {
        PostDropTargets(tokenBounds: tokenSlot.map(PostDropTargets.tokenBounds(in:)) ?? .zero, petBounds: pets)
    }
}

private struct PostBoardPreference: PreferenceKey {
    static let defaultValue = PostBoardMeasurements()
    static func reduce(value: inout PostBoardMeasurements, nextValue: () -> PostBoardMeasurements) {
        let next = nextValue()
        value.tokenSlot = next.tokenSlot ?? value.tokenSlot
        value.pets.merge(next.pets) { _, new in new }
        value.portraits.merge(next.portraits) { _, new in new }
    }
}

private struct PostTokenDrag: Equatable {
    let start: CGPoint
    let location: CGPoint
}

struct PostBoardView: View {
    let presentation: PostPresentation
    let minimumHeight: CGFloat
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var portraitHeight = 48.0
    @State private var scene = PostScene(size: .zero)
    @State private var measurements = PostBoardMeasurements()
    @State private var notice: String?
    @GestureState private var drag: PostTokenDrag?
    private var post: Post { presentation.post }
    private var pets: [Pet] { presentation.household.pets.filter(\.isActive) }
    private var stacked: Bool { typeSize.isAccessibilitySize }
    private var targets: PostDropTargets { measurements.targets }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            status
            if stacked {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    tokenColumn
                    petColumn
                }
            } else {
                PostSplitLayout {
                    tokenColumn
                    petColumn
                }
            }
            if let notice { Text(notice).font(PostType.caption).fixedSize(horizontal: false, vertical: true) }
            progress
        }
        .padding(Spacing.md)
        .frame(minHeight: minimumHeight, alignment: .topLeading)
        .background {
            GeometryReader { geometry in
                let input = PostSceneInput(size: geometry.size, post: post, pets: pets,
                                           targets: targets, portraits: measurements.portraits,
                                           stacked: stacked, reduceMotion: reduceMotion)
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .onChange(of: input, initial: true) { _, value in scene.show(value) }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .postSurface(emphasized: true)
        .coordinateSpace(name: "care-post")
        .onPreferenceChange(PostBoardPreference.self) { measurements = $0 }
        .onChange(of: drag) { _, value in
            scene.aim(from: value?.start, at: value?.location)
            guard let value else { presentation.token.release(); return }
            presentation.token.aim(at: targets.pet(at: value.location),
                                   progress: targets.progress(from: value.start, to: value.location, beckonedPetID: post.beckonedPetID))
        }
        .onDisappear { presentation.token.release() }
    }

    private var status: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Label(post.isComplete ? "Day complete" : post.canHand ? "Ready for care" : "Choose a pet",
                  systemImage: post.isComplete ? "checkmark.seal" : "circle.inset.filled")
                .font(PostType.caption).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.xs)

        }
    }

    private var tokenColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(post.nextRoutine?.petName ?? (post.isComplete ? "All cared for" : "Choose an animal"))
                    .font(PostType.heading).fixedSize(horizontal: false, vertical: true)
                Text(post.nextRoutine?.routineName ?? "Your next round starts with a name.")
                    .font(PostType.body).fixedSize(horizontal: false, vertical: true)
            }
            DesignTokens.surface.opacity(0)
                .frame(minHeight: portraitHeight * (stacked ? 1 : 2), maxHeight: .infinity)
                .background {
                    GeometryReader { geometry in
                        DesignTokens.surface.opacity(0).preference(key: PostBoardPreference.self,
                            value: PostBoardMeasurements(tokenSlot: geometry.frame(in: .named("care-post"))))
                    }
                }
                .overlay {
                    GeometryReader { geometry in
                        let hit = PostDropTargets.tokenBounds(in: CGRect(origin: .zero, size: geometry.size))
                        DesignTokens.surface.opacity(0)
                            .frame(width: hit.width, height: hit.height)
                            .contentShape(Rectangle())
                            .position(x: hit.midX, y: hit.midY)
                            .highPriorityGesture(tokenDrag)
                    }
                }
                .accessibilityHidden(true)
            Text("Drag the token to an animal, or use the button.")
                .font(PostType.caption).foregroundStyle(DesignTokens.muted).fixedSize(horizontal: false, vertical: true)
            ProgressView(value: presentation.token.progress)
                .tint(DesignTokens.ink).accessibilityLabel("Handoff progress")
                .opacity(drag == nil ? 0 : 1).accessibilityHidden(drag == nil)
            Button {
                notice = nil
                Task { _ = await presentation.hand() }
            } label: {
                HStack {
                    Text(presentation.isWorking ? "Saving care…" : "Hand")
                    Spacer(minLength: Spacing.xs)
                    Image(systemName: "arrow.right")
                }.frame(maxWidth: .infinity)
            }
            .buttonStyle(PostButtonStyle(primary: true))
            .disabled(!presentation.canHand)
            .accessibilityHint("Records the next care round for the selected animal.")
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var tokenDrag: some Gesture {
        DragGesture(coordinateSpace: .named("care-post"))
            .updating($drag) { value, state, _ in
                guard presentation.canHand, targets.tokenBounds.contains(value.startLocation) else { return }
                state = PostTokenDrag(start: value.startLocation, location: value.location)
            }
            .onEnded { value in
                let frames = targets
                guard frames.target(from: value.startLocation, to: value.location) != nil else {
                    presentation.token.release()
                    notice = "No animal received the token. Your care record is unchanged."
                    return
                }
                Task {
                    _ = await presentation.dropToken(from: value.startLocation, at: value.location, targets: frames)
                    notice = presentation.lastEffect == .missed ? "That animal is still waiting. Give the token to the selected animal to record care." : nil
                }
            }
    }

    private var petColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(pets) { pet in
                let remaining = post.remaining.filter { $0.petID == pet.id }.count
                let selected = post.beckonedPetID == pet.id
                Button {
                    notice = nil
                    Task {
                        if post.beckonedPetID == nil { await presentation.send(.beckon(petID: pet.id)) }
                        else {
                            _ = await presentation.hand(to: pet.id)
                            if presentation.lastEffect == .missed {
                                notice = "That animal is still waiting. Give the token to the selected animal to record care."
                            }
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        DesignTokens.surface.opacity(0)
                            .frame(minHeight: portraitHeight, maxHeight: .infinity)
                            .background {
                                GeometryReader { geometry in
                                    DesignTokens.surface.opacity(0).preference(key: PostBoardPreference.self,
                                        value: PostBoardMeasurements(portraits: [pet.id: geometry.frame(in: .named("care-post"))]))
                                }
                            }
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            HStack(spacing: Spacing.xxs) {
                                Text(pet.name).font(PostType.action).lineLimit(stacked ? nil : 1)
                                if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
                            }
                            Text(remaining == 0 ? "Care complete" : selected ? "Hand" : post.beckonedPetID == nil ? "Beckon" : "Give token")
                                .font(PostType.caption).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(Spacing.xxs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: PostRadius.control))
                    }
                    .padding(Spacing.xxs)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .overlay {
                        RoundedRectangle(cornerRadius: PostRadius.control)
                            .strokeBorder(DesignTokens.ink.opacity(selected ? 1 : 0.2), lineWidth: selected ? 2 : 1)
                    }
                    .background {
                        GeometryReader { geometry in
                            DesignTokens.surface.opacity(0).preference(key: PostBoardPreference.self,
                                value: PostBoardMeasurements(pets: [pet.id: geometry.frame(in: .named("care-post"))]))
                        }
                    }
                }
                .buttonStyle(PostPetPressStyle())
                .disabled(presentation.isWorking || post.isComplete || (post.beckonedPetID == nil && remaining == 0))
                .accessibilityLabel("\(pet.name). \(remaining.formatted()) rounds remaining.")
                .accessibilityHint(selected ? "Records this animal's next care round." : post.beckonedPetID == nil ? "Calls this animal forward." : "Giving the token here records a miss.")
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Divider().overlay(DesignTokens.muted)
            if stacked {
                progressLabel
                undo
            } else {
                HStack(spacing: Spacing.sm) {
                    progressLabel
                    Spacer(minLength: Spacing.xs)
                    undo
                }
            }
        }
    }

    private var progressLabel: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(post.completedCount, format: .number).font(PostType.heading).monospacedDigit()
                    .contentTransition(.numericText(value: Double(post.completedCount)))
                    .animation(reduceMotion ? nil : PostMotion.state, value: post.completedCount)
                Text("of").font(PostType.caption)
                Text(post.owedObligations.count, format: .number).font(PostType.heading).monospacedDigit()
            }
            Text("Rounds logged").font(PostType.caption)
        }
    }

    private var undo: some View {
        HStack(spacing: Spacing.xs) {
            if post.latestUndoableHand != nil {
                Button("Undo", systemImage: "arrow.uturn.backward") { Task { await presentation.send(.undoLatestHand) } }
                    .buttonStyle(PostButtonStyle()).disabled(presentation.isWorking)
                    .accessibilityHint("Reopens the most recent logged round still included in daily care.")
            }
            Button { presentation.sheet = .beckonGuide } label: { Image(systemName: "questionmark") }
                .buttonStyle(PostButtonStyle()).accessibilityLabel("How care works")
        }
    }
}

private struct PostPetPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(enabled ? (configuration.isPressed ? 0.55 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: PostRadius.control))
    }
}
