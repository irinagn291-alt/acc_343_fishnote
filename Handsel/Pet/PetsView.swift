import SwiftUI

struct PetsView: View {
    let presentation: PostPresentation
    @State private var editingPet: Pet?
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label("Your household", systemImage: "pawprint.fill").font(PostType.action)
                    Text("\(presentation.household.pets.count) pets · \(presentation.household.routines.filter(\.isActive).count) daily routines")
                        .font(PostType.body).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.lg).foregroundStyle(.white).carePanel(DesignTokens.careGreen)

                Button {
                    editingPet = nil
                    showingEditor = true
                } label: {
                    Label("Add a pet", systemImage: "plus").frame(maxWidth: .infinity)
                }.buttonStyle(PostButtonStyle(primary: true))

                ForEach(Array(presentation.household.pets.enumerated()), id: \.element.id) { index, pet in
                    petButton(pet, index: index)
                }
                if presentation.household.pets.isEmpty {
                    Text("Add your first pet, then give it a daily care round.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.padding(Spacing.lg)
        }
        .background(DesignTokens.warm)
        .navigationTitle("Pets")
        .postCloseButton()
        .navigationDestination(isPresented: $showingEditor) {
            PetEditor(presentation: presentation, original: editingPet)
        }
        .postStatus(presentation.petsState, presentation: presentation)
    }

    private func petButton(_ pet: Pet, index: Int) -> some View {
        let routines = presentation.household.routines.filter { $0.petID == pet.id && $0.isActive }
        let color = CareIdentity.color(at: index)
        return Button {
            editingPet = pet
            showingEditor = true
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    CareInitial(name: pet.name, color: DesignTokens.bg)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(pet.name).font(PostType.heading).fixedSize(horizontal: false, vertical: true)
                        Text(pet.isActive ? "\(routines.count) daily routines" : "Care paused")
                            .font(PostType.caption)
                    }
                    Spacer(minLength: Spacing.xs)
                    Label("Edit", systemImage: "pencil").font(PostType.caption)
                }
                Text(routines.isEmpty ? "No routines yet" : routines.sorted { $0.order < $1.order }.map(\.name).joined(separator: " · "))
                    .font(PostType.caption).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md).carePanel(color)
            .contentShape(RoundedRectangle(cornerRadius: PostRadius.surface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit \(pet.name), \(routines.count) daily routines, \(pet.isActive ? "active" : "paused")")
    }
}
