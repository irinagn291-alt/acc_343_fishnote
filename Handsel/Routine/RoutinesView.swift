import SwiftUI

struct RoutinesView: View {
    let presentation: PostPresentation
    @State private var editingRoutine: Routine?
    @State private var showingEditor = false
    @State private var selectedPetID: UUID?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var selectedPet: Pet? {
        presentation.household.pets.first { $0.id == selectedPetID }
            ?? presentation.household.pets.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Daily care order").font(PostType.heading)
                    Text("Choose a pet, then tap Edit. Rounds run from top to bottom.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.lg).foregroundStyle(.white).carePanel(DesignTokens.careGreen)

                if let pet = selectedPet {
                    petChooser
                    careSequence(for: pet)
                } else {
                    Text("Add your first pet to set up daily care rounds.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.padding(Spacing.lg)
        }
        // Reset the scroll position when switching schedules so a pet never
        // inherits another pet's offset with its heading out of view.
        .id(selectedPet?.id)
        .background(DesignTokens.warm)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                if presentation.household.pets.isEmpty {
                    presentation.sheet = .petEditor
                } else {
                    editingRoutine = nil
                    showingEditor = true
                }
            } label: {
                Label(presentation.household.pets.isEmpty ? "Add a pet" : "Add care round", systemImage: "plus")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PostButtonStyle(primary: true))
            .padding(Spacing.lg)
            .background(DesignTokens.warm)
        }
        .navigationTitle("Routines")
        .postCloseButton()
        .navigationDestination(isPresented: $showingEditor) {
            RoutineEditor(presentation: presentation, original: editingRoutine, preferredPetID: selectedPet?.id)
        }
        .postStatus(presentation.routinesState, presentation: presentation)
    }

    private var petChooser: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Choose a pet").font(PostType.action)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.xs) {
                    petChoices
                }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    petChoices
                }
            }
        }
    }

    private var petChoices: some View {
        ForEach(Array(presentation.household.pets.enumerated()), id: \.element.id) { index, pet in
            Button {
                selectedPetID = pet.id
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(pet.name)
                        .font(PostType.action)
                        .fixedSize(horizontal: false, vertical: true)
                    if pet.id == selectedPet?.id {
                        Image(systemName: "checkmark").accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 44)
                .padding(.vertical, Spacing.xxs)
                .carePanel(CareIdentity.color(at: index))
                .contentShape(RoundedRectangle(cornerRadius: PostRadius.surface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(pet.name)'s care rounds")
            .accessibilityAddTraits(pet.id == selectedPet?.id ? .isSelected : [])
        }
    }

    private func careSequence(for pet: Pet) -> some View {
        let index = presentation.household.pets.firstIndex { $0.id == pet.id } ?? 0
        let routines = presentation.household.routines.filter { $0.petID == pet.id }.sorted { $0.order < $1.order }
        let rowLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.sm))
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.sm) {
                CareInitial(name: pet.name, color: DesignTokens.bg)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(pet.name).font(PostType.heading).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    let count = routines.filter(\.isActive).count
                    Text(pet.isActive ? "\(count) daily \(count == 1 ? "round" : "rounds")" : "Care paused")
                        .font(PostType.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.padding(Spacing.md)
            ForEach(Array(routines.enumerated()), id: \.element.id) { step, routine in
                Divider().overlay(DesignTokens.ink.opacity(0.3))
                Button {
                    editingRoutine = routine
                    showingEditor = true
                } label: {
                    rowLayout {
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Text("\(step + 1)").font(PostType.action).monospacedDigit().frame(minWidth: 24)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(routine.name).font(PostType.action).fixedSize(horizontal: false, vertical: true)
                                Text(routine.isActive && pet.isActive ? "Every day" : "Paused")
                                    .font(PostType.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Label("Edit", systemImage: "pencil")
                            .font(PostType.caption)
                            .fixedSize()
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(DesignTokens.bg, in: RoundedRectangle(cornerRadius: PostRadius.control))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(Spacing.md)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
                .accessibilityLabel("Edit \(pet.name), step \(step + 1), \(routine.name)")
            }
            if routines.isEmpty {
                Text("No rounds yet. Add a care round below.").padding(Spacing.md)
            }
        }.carePanel(CareIdentity.color(at: index))
    }
}
