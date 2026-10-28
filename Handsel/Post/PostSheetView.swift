import SwiftUI

// Each destination is a real native screen above the still-mounted care post.
struct PostSheetView: View {
    let presentation: PostPresentation
    let destination: PostSheet

    var body: some View {
        NavigationStack {
            Group {
                switch destination {
                case .pets: PetsView(presentation: presentation)
                case .routines: RoutinesView(presentation: presentation)
                case .settings: PostSettingsView(presentation: presentation)
                case .history: PostHistoryView(presentation: presentation)
                case .beckonGuide: BeckonGuideView(presentation: presentation)
                case .petEditor: PetEditor(presentation: presentation)
                case .routineEditor: RoutineEditor(presentation: presentation)
                }
            }
            .buttonStyle(PostButtonStyle())
            .font(PostType.body)
            .foregroundStyle(DesignTokens.ink)
            .background(DesignTokens.bg)

        }
        .tint(DesignTokens.ink)
    }
}
