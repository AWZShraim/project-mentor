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
                    ProgressView().tint(Theme.purple)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(templates) { template in
                                Button {
                                    editingTemplate = template
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                        Text(template.exercises.map(\.name).joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .cardStyle()
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        Task { await delete(template) }
                                    }
                                }
                            }

                            Button {
                                showingCreateSheet = true
                            } label: {
                                Label("Create Day", systemImage: "plus")
                            }
                            .buttonStyle(.mentorPrimary)

                            if let message = errorMessage {
                                Text(message).foregroundStyle(Theme.danger).font(.footnote)
                            }
                        }
                        .padding(16)
                    }
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

    private func delete(_ template: WorkoutTemplate) async {
        guard let token = AuthTokenStore.current else { return }
        do {
            try await api.deleteTemplate(id: template.id, accessToken: token)
            templates.removeAll { $0.id == template.id }
        } catch {
            errorMessage = error.localizedDescription
        }
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
                        .textFieldStyle(.themed)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                if !selectedExercises.isEmpty {
                    Section {
                        ForEach(selectedExercises) { exercise in
                            Button {
                                deselect(exercise)
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.purple)
                                }
                                .cardStyle(padding: 12)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    } header: {
                        SectionHeader("Selected Exercises")
                    }
                }

                Section {
                    ForEach(availableExercises) { exercise in
                        Button {
                            select(exercise)
                        } label: {
                            Text(exercise.name)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardStyle(padding: 12)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                } header: {
                    SectionHeader("Exercises")
                }

                if let message = errorMessage {
                    Text(message).foregroundStyle(Theme.danger).font(.footnote)
                }
            }
            .listStyle(.plain)
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
                    ProgressView().tint(Theme.purple)
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
