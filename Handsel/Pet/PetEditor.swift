import SwiftUI

// An editor holds uncommitted form input locally; only Save enters the fold.
struct PetEditor: View {
    let presentation: PostPresentation
    let original: Pet?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var active: Bool
    @State private var saving = false
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    init(presentation: PostPresentation, original: Pet? = nil) {
        self.presentation = presentation
        self.original = original
        _name = State(initialValue: original?.name ?? "")
        _active = State(initialValue: original?.isActive ?? true)
    }

    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var dirty: Bool { name != (original?.name ?? "") || active != (original?.isActive ?? true) }

    var body: some View {
        Form {
            Section("Pet name") {
                TextField("Name", text: $name).textContentType(.name)
                    .focused($nameFocused).submitLabel(.done)
                    .onSubmit { nameFocused = false }
                if cleanName.isEmpty { Text("Give this pet a name to save.").font(PostType.caption).foregroundStyle(DesignTokens.muted) }
            }.listRowBackground(PostRowSurface())
            Section {
                Toggle("Include in daily care", isOn: $active)
            } footer: { Text("Paused pets stay in your household and keep their past care records.") }.listRowBackground(PostRowSurface())
            if let error {
                Section("Could not save") {
                    Text(error)
                    Button("Retry", systemImage: "arrow.clockwise", action: save)
                }.listRowBackground(PostRowSurface())
            }
            Section {
                Button(action: save) {
                    Label(saving ? "Saving pet…" : "Save pet", systemImage: "checkmark").frame(maxWidth: .infinity)
                }.buttonStyle(PostButtonStyle(primary: true)).disabled(cleanName.isEmpty || saving)
            }.listRowBackground(PostRowSurface())
            if let original {
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Remove \(original.name)", systemImage: "trash").foregroundStyle(DesignTokens.ink).frame(minHeight: 44)
                    }.disabled(saving)
                }.listRowBackground(PostRowSurface())
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(original == nil ? "Add a pet" : "Edit pet")
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(dirty || saving)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "xmark") {
                    if dirty { confirmDiscard = true } else { dismiss() }
                }.buttonStyle(PostButtonStyle()).disabled(saving)
            }
        }
        .confirmationDialog("Discard pet changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .confirmationDialog("Remove \(original?.name ?? "this pet")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove pet", role: .destructive) {
                guard let original else { return }
                saving = true
                Task {
                    await presentation.send(.removePet(original.id))
                    saving = false
                    if !presentation.household.pets.contains(where: { $0.id == original.id }) { dismiss() }
                    else { error = "The pet could not be removed. Try again." }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Their routines will leave today's care. Past care records are kept.") }
    }

    private func save() {
        guard !saving, !cleanName.isEmpty else { return }
        nameFocused = false
        saving = true
        let pet = Pet(id: original?.id ?? UUID(), name: cleanName, isActive: active)
        Task {
            await presentation.send(.savePet(pet))
            saving = false
            if presentation.household.pets.contains(pet) { PostFeedback.success(); dismiss() }
            else { error = "Your pet was not saved. Check the name and retry." }
        }
    }
}
