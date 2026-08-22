import SwiftUI

struct WorkoutTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var templates: [WorkoutTemplate] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingCreateSheet = false

    private let api = APIClient()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    List {
                        ForEach(templates) { template in
                            VStack(alignment: .leading) {
                                Text(template.name).font(.headline)
                                Text(template.exercises.map(\.name).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
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
                        }
                        .listRowSeparator(.hidden)

                        if let message = errorMessage {
                            Text(message).foregroundStyle(.red).font(.footnote)
                        }
                    }
                }
            }
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
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var allExercises: [Exercise] = []
    @State private var selectedExercises: [Exercise] = []
    @State private var searchText = ""
    @State private var isLoadingExercises = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let api = APIClient()

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
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Exercises") {
                    ForEach(availableExercises) { exercise in
                        Button {
                            select(exercise)
                        } label: {
                            Text(exercise.name)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let message = errorMessage {
                    Text(message).foregroundStyle(.red).font(.footnote)
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("New Day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
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
        return remaining.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
            _ = try await api.createTemplate(
                name: name,
                exerciseIds: selectedExercises.map(\.id),
                accessToken: token
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
