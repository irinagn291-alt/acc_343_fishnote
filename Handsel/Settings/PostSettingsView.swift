import SwiftUI

struct PostSettingsView: View {
    let presentation: PostPresentation
    @Environment(\.openURL) private var openURL
    @State private var confirmingReset = false
    @State private var resetting = false
    @State private var showingHistory = false
    @State private var showingGuide = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                careSummary
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Help with Fishnote").font(PostType.heading)
                    Button { showingGuide = true } label: {
                        destinationLabel("How care works", detail: "Choose a pet, hand the token, log care.", icon: "hand.point.up.left")
                            .padding(Spacing.md).carePanel(DesignTokens.ochre)
                            .contentShape(RoundedRectangle(cornerRadius: PostRadius.surface))
                    }.buttonStyle(.plain)
                    if let contactURL = PostSettings.contactURL {
                        Button { openURL(contactURL) } label: {
                            destinationLabel("Contact Fishnote", detail: contactURL.host ?? contactURL.absoluteString, icon: "envelope")
                                .padding(Spacing.md).carePanel(DesignTokens.sky)
                                .contentShape(RoundedRectangle(cornerRadius: PostRadius.surface))
                        }.buttonStyle(.plain)
                    }
                    Button {
                        presentation.sheet = nil
                        Task { await presentation.send(.restartOnboarding) }
                    } label: {
                        Label("Read the introduction", systemImage: "book")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label("Saved on this device", systemImage: "iphone").font(PostType.action)
                    Text(PostSettings.storageExplanation).font(PostType.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(role: .destructive) { confirmingReset = true } label: {
                        Label(resetting ? "Resetting…" : "Reset all data", systemImage: "trash")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(resetting)
                    Text("Removes this household's pets, routines and care history.")
                        .font(PostType.caption).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md).carePanel(DesignTokens.bg)
            }.padding(Spacing.lg)
        }
        .background(DesignTokens.warm)
        .navigationTitle("Settings")
        .postCloseButton()
        .navigationDestination(isPresented: $showingHistory) { PostHistoryView(presentation: presentation) }
        .navigationDestination(isPresented: $showingGuide) { BeckonGuideView(presentation: presentation) }
        .postStatus(presentation.settingsState, presentation: presentation)
        .confirmationDialog(PostSettings.resetTitle, isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset all data", role: .destructive) {
                resetting = true
                Task { await presentation.resetAllData(); resetting = false }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text(PostSettings.resetMessage) }
    }

    private var careSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Your care summary").font(PostType.action)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(presentation.streak, format: .number).font(PostType.count).monospacedDigit()
                Text("complete days in a row").fixedSize(horizontal: false, vertical: true)
            }
            Button { showingHistory = true } label: {
                Label("Open care log", systemImage: "clock.arrow.circlepath").frame(maxWidth: .infinity)
            }.buttonStyle(PostButtonStyle(primary: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg).foregroundStyle(.white).carePanel(DesignTokens.careGreen)
    }

    private func destinationLabel(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon).font(PostType.action).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(PostType.action)
                Text(detail).font(PostType.caption)
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right").accessibilityHidden(true)
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}
