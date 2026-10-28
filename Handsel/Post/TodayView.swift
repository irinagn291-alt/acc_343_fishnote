import SwiftUI

/// Today keeps one viewport-filling SpriteKit post mounted beneath the household sheets.
struct TodayView: View {
    let presentation: PostPresentation
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var post: Post { presentation.post }
    private var hasPets: Bool { presentation.household.pets.contains(where: \.isActive) }

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        if typeSize.isAccessibilitySize { header }
                        if case .error(let message) = presentation.todayState {
                            errorNotice(message)
                        } else if presentation.todayState == .empty {
                            PostEmptyView(
                                title: hasPets ? "Set the morning round." : "Make room for care.",
                                message: hasPets ? "Give each animal a care round, then return here to log it." : "Add a pet and a care round to start your mornings.",
                                action: hasPets ? "Add care round" : "Add a pet"
                            ) {
                                presentation.sheet = hasPets ? .routineEditor : .petEditor
                            }.frame(minHeight: viewport.size.height)
                        } else {
                            PostBoardView(presentation: presentation, minimumHeight: max(viewport.size.height - Spacing.xxl, 0))
                                .redacted(reason: presentation.todayState == .loading ? .placeholder : [])
                                .padding(.horizontal, Spacing.xl)
                                .padding(.vertical, Spacing.md)
                        }
                    }
                }
            }
            .background(DesignTokens.bg)
            .safeAreaInset(edge: .top, spacing: Spacing.xxs) {
                if !typeSize.isAccessibilitySize { header }
            }
            .safeAreaInset(edge: .bottom, spacing: Spacing.xxs) { footer }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Pets", systemImage: "pawprint") { presentation.sheet = .pets }
                        .buttonStyle(PostButtonStyle())
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { presentation.sheet = .routines } label: { Image(systemName: "checklist") }
                        .accessibilityLabel("Routines").buttonStyle(PostButtonStyle())
                    Button { presentation.sheet = .settings } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings").buttonStyle(PostButtonStyle())
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(PostType.caption).foregroundStyle(DesignTokens.muted)
            Text("Morning care").font(PostType.title).fixedSize(horizontal: false, vertical: true)
            Text(post.isComplete ? "Every round is logged. Your day is complete." : "Log each animal's morning care round.")
                .font(PostType.body).foregroundStyle(DesignTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.xs)
        .background(DesignTokens.bg)
    }

    private var footer: some View {
        Button { presentation.sheet = .history } label: {
            HStack(spacing: Spacing.md) {
                Text(presentation.streak, format: .number).font(PostType.heading).monospacedDigit()
                    .contentTransition(.numericText(value: Double(presentation.streak)))
                    .animation(reduceMotion ? nil : PostMotion.state, value: presentation.streak)
                if typeSize.isAccessibilitySize {
                    Text("Care log").font(PostType.caption)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Complete days in a row").font(PostType.caption).fontWeight(.semibold)
                        Text("Open the care log").font(PostType.caption).foregroundStyle(DesignTokens.muted)
                    }
                }
                Spacer(minLength: Spacing.xs)
                Image(systemName: "arrow.up.right").font(PostType.caption)
            }.frame(maxWidth: .infinity)
        }
        .buttonStyle(PostButtonStyle())
        .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.xs)
        .background(.regularMaterial)
    }

    private func errorNotice(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Care could not be loaded.").font(PostType.heading)
            Text(message)
            Button("Retry", systemImage: "arrow.clockwise") { Task { await presentation.load() } }
                .buttonStyle(PostButtonStyle(primary: true))
        }.padding(Spacing.xl).postSurface().padding(Spacing.xl)
    }
}
