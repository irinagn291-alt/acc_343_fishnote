import SwiftUI

struct BeckonGuideView: View {
    let presentation: PostPresentation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Log a care round").font(PostType.heading)
                    Text("The token records one finished care round for the pet you choose.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md).foregroundStyle(.white).carePanel(DesignTokens.careGreen)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    instruction(1, "Beckon", detail: "Choose a pet with care still due. Its name appears beside the token.", color: DesignTokens.mint)
                    instruction(2, "Hand", detail: "Tap Hand or drag the token to that pet. Its next unfinished care round is saved on this device.", color: DesignTokens.ochre)
                    instruction(3, "Finish", detail: "Log every care round to complete the day. Undo restores the last round and selects that pet again.", color: DesignTokens.sky)
                }
                Text("Giving the token to another pet records a miss, not care. The selected pet keeps its place.")
                    .font(PostType.caption).fixedSize(horizontal: false, vertical: true)
            }.padding(Spacing.lg)
        }
        .background(DesignTokens.warm)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { presentation.sheet = nil } label: {
                Label("Return to care", systemImage: "arrow.right").frame(maxWidth: .infinity)
            }
            .buttonStyle(PostButtonStyle(primary: true))
            .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.sm)
            .background(DesignTokens.warm)
        }
        .navigationTitle("How care works")
        .postCloseButton()
    }

    private func instruction(_ number: Int, _ title: String, detail: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("\(number)").font(PostType.action)
                .frame(width: 36, height: 36)
                .background(color, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(PostType.action)
                Text(detail).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
