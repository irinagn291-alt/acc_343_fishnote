import SwiftUI

// Onboarding describes the job and commits completion through presentation.
struct PostOnboardingView: View {
    let presentation: PostPresentation
    @State private var page = 0
    @State private var saving = false
    @State private var error = false

    private let titles = ["A round for every pet.", "Beckon. Then hand.", "A small record of care."]
    private let messages = [
        "Give each animal a name and a daily care round. Keep morning care together in one place.",
        "Choose a pet with Beckon. Hand it the token to log the next round. A handoff to another pet never counts as care.",
        "Finish every care round due to complete the day. Your household and its history stay on this device."
    ]
    private let artwork = ["hns_Onboarding1", "hns_Onboarding2", "hns_Onboarding3"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text("Morning care, together.").font(PostType.caption).foregroundStyle(DesignTokens.muted)
                    Image(artwork[page]).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 320)
                        .accessibilityHidden(true).background(DesignTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: PostRadius.surface))
                    Text(titles[page]).font(PostType.title).fixedSize(horizontal: false, vertical: true)
                    Text(messages[page]).font(PostType.body).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Spacing.xs) {
                        Text(page + 1, format: .number)
                        Text("of")
                        Text(titles.count, format: .number)
                    }.font(PostType.caption).foregroundStyle(DesignTokens.muted)
                    if error { Text("The introduction could not be saved. Please try again.") }
                }.padding(Spacing.xl)
            }
            .background(DesignTokens.bg)
            .safeAreaInset(edge: .bottom) {
                Button(action: next) {
                    Text(saving ? "Saving…" : page == 2 ? "Start caring" : "Continue").frame(maxWidth: .infinity)
                }.buttonStyle(PostButtonStyle(primary: true)).disabled(saving)
                    .padding(Spacing.xl).background(.regularMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip", systemImage: "arrow.right.to.line") { complete() }
                        .buttonStyle(PostButtonStyle()).disabled(saving)
                }
            }
        }
    }

    private func next() { if page < 2 { page += 1 } else { complete() } }
    private func complete() {
        guard !saving else { return }
        saving = true
        Task {
            await presentation.send(.completeOnboarding)
            saving = false
            error = !presentation.onboarding.isComplete
        }
    }
}
