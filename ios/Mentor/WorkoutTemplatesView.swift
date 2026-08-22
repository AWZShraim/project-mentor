import SwiftUI

struct WorkoutTemplatesView: View {
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
                } else if let message = errorMessage {
                    Text(message).foregroundStyle(.red).padding()
                } else if templates.isEmpty {
                    ContentUnavailableView(
                        "No splits yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Create a split to save a reusable exercise list")
                    )
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
                    }
                }
            }
            .navigationTitle("Splits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
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
    @State private var selectedExercises: [Exercise] = []
    @State private var showingExercisePicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let api = APIClient()

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Push Day", text: $name)
                }

                Section("Exercises") {
                    ForEach(selectedExercises) { exercise in
                        Text(exercise.name)
                    }
                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add Exercises", systemImage: "plus")
                    }
                }

                if let message = errorMessage {
                    Text(message).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("New Split")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || selectedExercises.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercises in
                    selectedExercises = exercises
                    showingExercisePicker = false
                }
            }
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
