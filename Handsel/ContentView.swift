import SwiftUI

// The root keeps the post mounted while native destinations own their stacks.
struct ContentView: View {
    @State private var presentation = PostPresentation(storage: HouseholdStore(), successFeedback: { PostFeedback.success() })
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var presentation = presentation
        Group {
            if presentation.shouldShowOnboarding {
                PostOnboardingView(presentation: presentation)
            } else {
                TodayView(presentation: presentation)
            }
        }
        .buttonStyle(PostButtonStyle())
        .font(PostType.body)
        .foregroundStyle(DesignTokens.ink)
        .tint(DesignTokens.ink)
        .background(DesignTokens.bg.ignoresSafeArea())
        .sheet(item: $presentation.sheet) { sheet in
            PostSheetView(presentation: presentation, destination: sheet)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(PostRadius.surface)
        }
        .task { await presentation.load() }
        .overlay {
            if let diagnostic = presentation.reviewDiagnostic {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Simulator review diagnostic").font(PostType.heading)
                    Text(diagnostic).font(PostType.body)
                }.padding(Spacing.xl).postSurface(emphasized: true).padding(Spacing.xl)
            }
        }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) }
                catch { return }
                await presentation.refreshDay()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            Task {
                if phase == .active { await presentation.refreshDay() }
                else { await presentation.flush() }
            }
        }
    }
}
