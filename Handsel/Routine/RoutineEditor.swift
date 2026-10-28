import SwiftUI

// Stable order is validated before the routine command reaches persistence.
struct RoutineEditor: View {
    let presentation: PostPresentation
    let original: Routine?
    private let initialPetID: UUID?
    private let initialOrder: String
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var petID: UUID?
    @State private var order: String
    @State private var active: Bool
    @State private var saving = false
    @State private var error: String?
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    @FocusState private var focus: Field?
    private enum Field: Hashable { case name, order }

    init(presentation: PostPresentation, original: Routine? = nil, preferredPetID: UUID? = nil) {
        self.presentation = presentation
        self.original = original
        let startingPetID = original?.petID ?? preferredPetID ?? presentation.household.pets.first?.id
        initialPetID = startingPetID
        initialOrder = (original?.order ?? (presentation.household.routines.map(\.order).max() ?? 0) + 1).formatted(.number.grouping(.never))
        _name = State(initialValue: original?.name ?? "")
        _petID = State(initialValue: startingPetID)
        _order = State(initialValue: (original?.order ?? (presentation.household.routines.map(\.order).max() ?? 0) + 1).formatted(.number.grouping(.never)))
        _active = State(initialValue: original?.isActive ?? true)
    }

    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var validOrder: Int? { try? Int(order, format: .number.grouping(.never)) }
    private var dirty: Bool {
        name != (original?.name ?? "") || petID != initialPetID || order != initialOrder || active != (original?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section {
                TextField("Care round name", text: $name).focused($focus, equals: .name).submitLabel(.next)
                    .onSubmit { focus = .order }
                Picker("Pet", selection: $petID) {
                    Text("Choose a pet").tag(Optional<UUID>.none)
                    ForEach(presentation.household.pets) { pet in Text(pet.name).tag(Optional(pet.id)) }
                }
                TextField("Order", text: $order).keyboardType(.numberPad).focused($focus, equals: .order)
                    .onChange(of: order) { oldValue, newValue in
                        if !newValue.allSatisfy(\.isWholeNumber) { order = oldValue }
                    }
                Toggle("Include every day", isOn: $active)
            } header: { Text("Care round") } footer: { Text("The lowest order goes first. The next unfinished round is recorded for the animal you choose.") }.listRowBackground(PostRowSurface())
            if cleanName.isEmpty || petID == nil || validOrder == nil {
                Section { Text("Enter a name, choose a pet and set a whole-number order.").font(PostType.caption) }.listRowBackground(PostRowSurface())
            }
            if let error {
                Section("Could not save") {
                    Text(error)
                    Button("Retry", systemImage: "arrow.clockwise", action: save)
                }.listRowBackground(PostRowSurface())
            }
            Section {
                Button(action: save) {
                    Label(saving ? "Saving care round…" : "Save care round", systemImage: "checkmark").frame(maxWidth: .infinity)
                }.buttonStyle(PostButtonStyle(primary: true))
                    .disabled(saving || cleanName.isEmpty || petID == nil || validOrder == nil)
            }.listRowBackground(PostRowSurface())
            if original != nil {
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Remove care round", systemImage: "trash").foregroundStyle(DesignTokens.ink).frame(minHeight: 44)
                    }.disabled(saving)
                }.listRowBackground(PostRowSurface())
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(original == nil ? "Add care round" : "Edit care round")
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(dirty || saving)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "xmark") { if dirty { confirmDiscard = true } else { dismiss() } }
                    .buttonStyle(PostButtonStyle()).disabled(saving)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Button("Done", systemImage: "checkmark") { focus = nil }
            }
        }
        .confirmationDialog("Discard care round changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .confirmationDialog("Remove \(original?.name ?? "this care round")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove care round", role: .destructive) {
                guard let original else { return }
                saving = true
                Task {
                    await presentation.send(.removeRoutine(original.id))
                    saving = false
                    if !presentation.household.routines.contains(where: { $0.id == original.id }) { dismiss() }
                    else { error = "The care round was not removed. Your records are unchanged. Please try again." }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes the round from daily care. Existing history is kept.") }
    }

    private func save() {
        guard !saving, !cleanName.isEmpty, let petID, let validOrder, validOrder >= 0 else { return }
        focus = nil
        saving = true
        let routine = Routine(id: original?.id ?? UUID(), petID: petID, name: cleanName, isActive: active, order: validOrder)
        Task {
            await presentation.send(.saveRoutine(routine))
            saving = false
            if presentation.household.routines.contains(routine) { PostFeedback.success(); dismiss() }
            else { error = "The care round was not saved. Check its pet and order, then retry." }
        }
    }
}
