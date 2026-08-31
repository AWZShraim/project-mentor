import SwiftUI

struct ExercisePickerView: View {
    var allowsMultipleSelection: Bool = true
    var onDone: ([Exercise]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [Exercise] = []
    @State private var searchText = ""
    @State private var selectedIDs: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let api = APIClient()

    var body: some View {
        NavigationStack {
            List {
                if !selectedExercises.isEmpty {
                    Section {
                        ForEach(selectedExercises) { exercise in
                            Button {
                                toggle(exercise)
                            } label: {
                                exerciseRow(exercise)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        }
                    } header: {
                        SectionHeader("Selected Exercises")
                    }
                }

                Section {
                    ForEach(availableExercises) { exercise in
                        Button {
                            toggle(exercise)
                        } label: {
                            exerciseRow(exercise)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    }
                } header: {
                    SectionHeader(searchText.isEmpty ? "All Exercises" : "Results")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Choose Exercises")
            .darkNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if allowsMultipleSelection {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            onDone(exercises.filter { selectedIDs.contains($0.id) })
                        }
                        .disabled(selectedIDs.isEmpty)
                    }
                }
            }
            .dismissKeyboardOnTap()
            .overlay {
                if isLoading {
                    ProgressView()
                } else if let message = errorMessage {
                    Text(message).foregroundStyle(Theme.danger).padding()
                }
            }
            .task {
                await load()
            }
        }
    }

    private var selectedExercises: [Exercise] {
        exercises.filter { selectedIDs.contains($0.id) }
    }

    private var availableExercises: [Exercise] {
        let remaining = exercises.filter { !selectedIDs.contains($0.id) }
        guard !searchText.isEmpty else { return remaining }
        return remaining
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { relevanceRank($0.name, matching: searchText) < relevanceRank($1.name, matching: searchText) }
    }

    private func toggle(_ exercise: Exercise) {
        if allowsMultipleSelection {
            if selectedIDs.contains(exercise.id) {
                selectedIDs.remove(exercise.id)
            } else {
                selectedIDs.insert(exercise.id)
            }
        } else {
            onDone([exercise])
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                Text(metadataLine(exercise))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if selectedIDs.contains(exercise.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.purple)
            }
        }
        .cardStyle(padding: 12)
    }

    private func metadataLine(_ exercise: Exercise) -> String {
        var parts: [String] = []
        if let equipment = exercise.equipment { parts.append(equipment.capitalized) }
        if let muscles = exercise.muscleGroups, !muscles.isEmpty {
            parts.append(muscles.joined(separator: ", "))
        }
        return parts.joined(separator: " \u{00B7} ")
    }

    private func load() async {
        guard let token = AuthTokenStore.current else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            exercises = try await api.listExercises(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
