import SwiftUI
import UIKit

// The live frame's single type, spacing, shape and motion vocabulary.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let huge: CGFloat = 40
    static let giant: CGFloat = 48
}

enum PostRadius {
    static let surface: CGFloat = 16
    static let control: CGFloat = 10
}

enum PostType {
    static let count = Font.custom(DesignTokens.fontFamily, size: 48, relativeTo: .largeTitle)
    static let title = Font.custom(DesignTokens.fontFamily, size: 35, relativeTo: .largeTitle)
    static let heading = Font.custom(DesignTokens.fontFamily, size: 27, relativeTo: .title2)
    static let action = Font.custom(DesignTokens.fontFamily, size: 21, relativeTo: .headline)
    static let body = Font.system(.body)
    static let caption = Font.system(.subheadline)
}

enum PostMotion {
    static let state = Animation.spring(response: 0.18, dampingFraction: 1)
}

struct PostButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(primary ? PostType.action : PostType.body)
            .foregroundStyle(DesignTokens.ink)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(minWidth: 44, minHeight: 44)
            .background(primary ? DesignTokens.accent : DesignTokens.surface,
                        in: RoundedRectangle(cornerRadius: PostRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: PostRadius.control)
                    .strokeBorder(DesignTokens.ink.opacity(primary ? 1 : 0.25), lineWidth: primary ? 2 : 1)
            }
            .opacity(enabled ? (configuration.isPressed ? 0.55 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: PostRadius.control))
    }
}

// Shared identity treatment for the household and its ordered care sections.
enum CareIdentity {
    static func color(at index: Int) -> Color {
        [DesignTokens.mint, DesignTokens.sky, DesignTokens.ochre][index % 3]
    }
}

struct CareInitial: View {
    let name: String
    let color: Color

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(PostType.heading)
            .foregroundStyle(DesignTokens.ink)
            .frame(width: 48, height: 48)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(DesignTokens.ink, lineWidth: 2))
            .accessibilityHidden(true)
    }
}

extension View {
    func carePanel(_ color: Color) -> some View {
        background(color, in: RoundedRectangle(cornerRadius: PostRadius.surface))
            .overlay {
                RoundedRectangle(cornerRadius: PostRadius.surface)
                    .strokeBorder(DesignTokens.ink, lineWidth: 2)
            }
    }
}

struct PostSurface: ViewModifier {
    var emphasized = false
    func body(content: Content) -> some View {
        content
            .background(DesignTokens.surface.opacity(0.7))
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PostRadius.surface))
            .clipShape(RoundedRectangle(cornerRadius: PostRadius.surface))
            .overlay {
                RoundedRectangle(cornerRadius: PostRadius.surface)
                    .strokeBorder(DesignTokens.ink.opacity(emphasized ? 1 : 0.2), lineWidth: emphasized ? 2 : 1)
            }
    }
}

extension View {
    func postSurface(emphasized: Bool = false) -> some View {
        modifier(PostSurface(emphasized: emphasized))
    }
}

struct PostEmptyView: View {
    let title: String
    let message: String
    let action: String
    var art = "hns_EmptyHome"
    let perform: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Image(art)
                .resizable().scaledToFit()
                .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 240)
                .accessibilityHidden(true)
                .background(DesignTokens.surface)
            Text(title).font(PostType.title).fixedSize(horizontal: false, vertical: true)
            Text(message).font(PostType.body).foregroundStyle(DesignTokens.muted)
            Button(action: perform) {
                Label(action, systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PostButtonStyle(primary: true))
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignTokens.bg)
    }
}

// Propose uneven widths while allowing both native columns their full height.
struct PostSplitLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let available = width - Spacing.md
        let left = subviews[0].sizeThatFits(.init(width: available * 0.58, height: nil))
        let right = subviews[1].sizeThatFits(.init(width: available * 0.42, height: nil))
        return CGSize(width: width, height: max(left.height, right.height, proposal.height ?? 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let available = bounds.width - Spacing.md
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: .init(width: available * 0.58, height: bounds.height))
        subviews[1].place(at: CGPoint(x: bounds.minX + available * 0.58 + Spacing.md, y: bounds.minY), anchor: .topLeading,
                          proposal: .init(width: available * 0.42, height: bounds.height))
    }
}

@MainActor
enum PostFeedback {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

struct PostRowSurface: View {
    var body: some View {
        RoundedRectangle(cornerRadius: PostRadius.surface)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: PostRadius.surface)
                    .strokeBorder(DesignTokens.ink.opacity(0.16), lineWidth: 1)
            }
    }
}

struct PostCloseButton: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close", systemImage: "xmark") { dismiss() }.buttonStyle(PostButtonStyle())
            }
        }
    }
}

extension View {
    func postCloseButton() -> some View { modifier(PostCloseButton()) }
}

struct PostStatus: ViewModifier {
    let state: PostContentState
    let presentation: PostPresentation

    func body(content: Content) -> some View {
        content
            .redacted(reason: state == .loading ? .placeholder : [])
            .safeAreaInset(edge: .top) {
                if case .error(let message) = state {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Your changes could not be loaded or saved.").font(PostType.action)
                        Text(message).font(PostType.caption)
                        Button("Retry", systemImage: "arrow.clockwise") { Task { await presentation.load() } }
                            .buttonStyle(PostButtonStyle(primary: true))
                    }.padding(Spacing.md).postSurface().padding(Spacing.md)
                }
            }
    }
}

extension View {
    func postStatus(_ state: PostContentState, presentation: PostPresentation) -> some View {
        modifier(PostStatus(state: state, presentation: presentation))
    }
}
