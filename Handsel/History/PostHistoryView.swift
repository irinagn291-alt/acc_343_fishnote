import SwiftUI

struct PostHistoryView: View {
    let presentation: PostPresentation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                dailyProgress
                ForEach(presentation.history, id: \.daykey) { post in
                    dayLedger(post)
                }
                if presentation.history.isEmpty {
                    Text("Your logged rounds will appear here, grouped by day and pet.")
                }
            }.padding(Spacing.lg)
        }
        .background(DesignTokens.warm)
        .navigationTitle("Care log")
        .postCloseButton()
        .postStatus(presentation.todayState, presentation: presentation)
    }

    private var dailyProgress: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Today's care").font(PostType.action)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(presentation.post.completedCount, format: .number)
                    Text("of")
                    Text(presentation.post.owedObligations.count, format: .number)
                }.font(PostType.count).monospacedDigit()
                Text("rounds logged").font(PostType.caption)
            }.fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            ProgressView(value: Double(presentation.post.completedCount), total: Double(max(1, presentation.post.owedObligations.count)))
                .tint(DesignTokens.mint)
                .accessibilityLabel("Today's completed care")
            Text("\(presentation.streak) complete days in a row").font(PostType.caption)
            Button {
                presentation.sheet = nil
            } label: {
                Label(presentation.post.isComplete ? "View today's care" : "Continue today's care", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(PostButtonStyle(primary: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg).foregroundStyle(.white).carePanel(DesignTokens.careGreen)
    }

    private func dayLedger(_ post: Post) -> some View {
        let petIDs = post.obligations.reduce(into: [UUID]()) { ids, routine in
            if !ids.contains(routine.petID) { ids.append(routine.petID) }
        }
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    dayTitle(post)
                    Spacer(minLength: Spacing.xs)
                    dayStatus(post)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    dayTitle(post)
                    dayStatus(post)
                }
            }
            ForEach(petIDs, id: \.self) { petID in
                let routines = post.obligations.filter { $0.petID == petID }
                VStack(alignment: .leading, spacing: 0) {
                    Text(routines.first?.petName ?? "Pet")
                        .font(PostType.action)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
                        .background(DesignTokens.mint)
                    ForEach(routines) { routine in
                        ledgerRow(routine, post: post)
                        Divider()
                    }
                }
            }
        }.padding(.bottom, Spacing.sm)
    }

    private func dayTitle(_ post: Post) -> some View {
        Group {
            if let date = PostCalendar().date(for: post.daykey) {
                Text(date, format: .dateTime.month(.abbreviated).day())
            }
        }.font(PostType.heading)
    }

    private func dayStatus(_ post: Post) -> some View {
        Label(post.isComplete ? "Complete" : post.owedObligations.isEmpty ? "Archived" : "In progress",
              systemImage: post.isComplete ? "checkmark.circle.fill" : "clock")
            .font(PostType.caption).fontWeight(.semibold)
            .padding(Spacing.xs)
            .background(post.isComplete ? DesignTokens.mint : DesignTokens.ochre)
    }

    private func ledgerRow(_ routine: RoutineObligation, post: Post) -> some View {
        let logged = post.completedRoutineIDs.contains(routine.routineID)
        return HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: logged ? "checkmark.circle.fill" : routine.isOwed ? "clock" : "archivebox")
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(routine.routineName).fixedSize(horizontal: false, vertical: true)
                if !routine.isOwed { Text("Archived care").font(PostType.caption) }
            }
            Spacer(minLength: Spacing.xxs)
            Text(logged ? "Logged" : routine.isOwed ? "Due" : "Archived")
                .font(PostType.caption).fontWeight(.semibold)
                .padding(.horizontal, Spacing.xs).padding(.vertical, Spacing.xxs)
                .background(logged ? DesignTokens.mint : routine.isOwed ? DesignTokens.ochre : DesignTokens.surface)
        }.frame(minHeight: 44).padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xxs)
    }
}
