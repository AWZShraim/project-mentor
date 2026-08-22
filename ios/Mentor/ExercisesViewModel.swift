import Foundation
import Combine

/// One exercise's live-editable row on the Exercises page. A class (not a
/// struct) so each row can be independently observed/mutated without
/// re-rendering the whole list, and so `serverID` can be filled in after
/// the first successful save without needing to replace the array entry.
final class EditableWorkoutEntry: ObservableObject, Identifiable {
    let id = UUID()
    var serverID: String?
    let exercise: Exercise
    @Published var sets: [SetInputRow]

    init(exercise: Exercise, sets: [SetInputRow]? = nil, serverID: String? = nil) {
        self.exercise = exercise
        self.sets = sets ?? [SetInputRow(setNumber: 1)]
        self.serverID = serverID
    }
}

@MainActor
final class ExercisesViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var entries: [EditableWorkoutEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient()
    private var saveTasks: [UUID: Task<Void, Never>] = [:]

    func loadEntries() async {
        guard let token = AuthTokenStore.current else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let dateString = DateFormatting.dateOnly.string(from: selectedDate)
            let records = try await api.listWorkoutLogs(date: dateString, accessToken: token)
            entries = records.map { record in
                let rows = record.sets.map { set in
                    SetInputRow(
                        setNumber: set.setNumber,
                        reps: set.reps.map(String.init) ?? "",
                        weight: set.weight.map(formattedNumber) ?? "",
                        weightUnit: set.weightUnit ?? "kg",
                        durationSeconds: set.durationSeconds.map(String.init) ?? "",
                        distance: set.distance.map(formattedNumber) ?? "",
                        distanceUnit: set.distanceUnit ?? "km"
                    )
                }
                return EditableWorkoutEntry(
                    exercise: record.exercise,
                    sets: rows.isEmpty ? nil : rows,
                    serverID: record.id
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        Task { await loadEntries() }
    }

    func goToNextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        Task { await loadEntries() }
    }

    func addExercises(_ exercises: [Exercise]) {
        for exercise in exercises {
            entries.append(EditableWorkoutEntry(exercise: exercise))
        }
    }

    func addSet(to entry: EditableWorkoutEntry) {
        entry.sets.append(SetInputRow(setNumber: entry.sets.count + 1))
    }

    /// Debounces edits so we don't fire a network request per keystroke -
    /// cancels any pending save for this entry and reschedules.
    func scheduleSave(for entry: EditableWorkoutEntry) {
        saveTasks[entry.id]?.cancel()
        saveTasks[entry.id] = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await save(entry)
        }
    }

    private func save(_ entry: EditableWorkoutEntry) async {
        guard let token = AuthTokenStore.current else { return }

        let validRows = entry.sets.filter { !$0.isBlank }
        guard !validRows.isEmpty else { return }
        let payloadSets = validRows.map { $0.asPayload() }

        do {
            if let serverID = entry.serverID {
                _ = try await api.updateWorkoutLog(
                    id: serverID, sets: payloadSets, accessToken: token
                )
            } else {
                let loggedAtString = DateFormatting.dateTime.string(from: combinedDateTime())
                let payload = WorkoutLogCreatePayload(
                    exerciseId: entry.exercise.id,
                    loggedAt: loggedAtString,
                    notes: nil,
                    sets: payloadSets
                )
                let record = try await api.createWorkoutLog(payload, accessToken: token)
                entry.serverID = record.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeEntry(_ entry: EditableWorkoutEntry) {
        entries.removeAll { $0.id == entry.id }
        saveTasks[entry.id]?.cancel()
        guard let serverID = entry.serverID, let token = AuthTokenStore.current else { return }
        Task {
            try? await api.deleteWorkoutLog(id: serverID, accessToken: token)
        }
    }

    private func combinedDateTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second
        return calendar.date(from: dateComponents) ?? selectedDate
    }
}
