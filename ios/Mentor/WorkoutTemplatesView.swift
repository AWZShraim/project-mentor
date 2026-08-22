import SwiftUI

struct WorkoutTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var templates: [WorkoutTemplate] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingCreateSheet = false
    @State private var editingTemplate: WorkoutTemplate?

    private let api = APIClient()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    List {
                        ForEach(templates) { template in
                            Button {
                                editingTemplate = template
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(template.name)
                                        .font(.headline)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(template.exercises.map(\.name).joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Theme.surface)
                        }
                        .onDelete { offsets in
                            Task { await delete(at: offsets) }
                        }

                        Section {
                            Button {
                                showingCreateSheet = true
                            } label: {
                                Label("Create Day", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.purple)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                        if let message = errorMessage {
                            Text(message).foregroundStyle(Theme.danger).font(.footnote)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Theme.background)
                }
            }
            .background(Theme.background)
            .navigationTitle("Days")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCreateSheet, onDismiss: {
                Task { await load() }
            }) {
                CreateWorkoutTemplateView()
            }
            .sheet(item: $editingTemplate, onDismiss: {
                Task { await load() }
            }) { template in
                CreateWorkoutTemplateView(existingTemplate: template)
            }
            .task {
                await load()
            }
        }
    }

    private func load() async {
        guard let token = AuthTokenStore.current else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            templates = try await api.listTemplates(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) async {
        guard let token = AuthTokenStore.current else { return }
        for index in offsets {
            let template = templates[index]
            do {
                try await api.deleteTemplate(id: template.id, accessToken: token)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        await load()
    }
}

struct CreateWorkoutTemplateView: View {
    var existingTemplate: WorkoutTemplate?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var allExercises: [Exercise] = []
    @State private var selectedExercises: [Exercise]
    @State private var searchText = ""
    @State private var isLoadingExercises = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let api = APIClient()

    init(existingTemplate: WorkoutTemplate? = nil) {
        self.existingTemplate = existingTemplate
        _name = State(initialValue: existingTemplate?.name ?? "")
        _selectedExercises = State(initialValue: existingTemplate?.exercises ?? [])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Day name (e.g. Push Day)", text: $name)
                }

                if !selectedExercises.isEmpty {
                    Section("Selected Exercises") {
                        ForEach(selectedExercises) { exercise in
                            Button {
                                deselect(exercise)
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.purple)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Theme.surface)
                    }
                }

                Section("Exercises") {
                    ForEach(availableExercises) { exercise in
                        Button {
                            select(exercise)
                        } label: {
                            Text(exercise.name)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Theme.surface)
                }

                if let message = errorMessage {
                    Text(message).foregroundStyle(Theme.danger).font(.footnote)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle(existingTemplate == nil ? "New Day" : "Edit Day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingTemplate == nil ? "Create" : "Save") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || selectedExercises.isEmpty || isSaving)
                }
            }
            .overlay {
                if isLoadingExercises {
                    ProgressView()
                }
            }
            .task {
                await loadExercises()
            }
        }
    }

    private var availableExercises: [Exercise] {
        let selectedIDs = Set(selectedExercises.map(\.id))
        let remaining = allExercises.filter { !selectedIDs.contains($0.id) }
        guard !searchText.isEmpty else { return remaining }
        return remaining
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { relevanceRank($0.name, matching: searchText) < relevanceRank($1.name, matching: searchText) }
    }

    private func select(_ exercise: Exercise) {
        selectedExercises.append(exercise)
    }

    private func deselect(_ exercise: Exercise) {
        selectedExercises.removeAll { $0.id == exercise.id }
    }

    private func loadExercises() async {
        guard let token = AuthTokenStore.current else { return }
        isLoadingExercises = true
        defer { isLoadingExercises = false }
        do {
            allExercises = try await api.listExercises(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let token = AuthTokenStore.current else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let existingTemplate {
                _ = try await api.updateTemplate(
                    id: existingTemplate.id,
                    name: name,
                    exerciseIds: selectedExercises.map(\.id),
                    accessToken: token
                )
            } else {
                _ = try await api.createTemplate(
                    name: name,
                    exerciseIds: selectedExercises.map(\.id),
                    accessToken: token
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
