import Foundation
import SwiftUI

private struct SetInputRow: Identifiable {
    let id = UUID()
    var setNumber: Int
    var reps: String = ""
    var weight: String = ""
    var weightUnit: String = "kg"
    var durationSeconds: String = ""
    var distance: String = ""
    var distanceUnit: String = "km"
}

struct WorkoutSetsFormView: View {
    let date: Date
    let exercises: [Exercise]

    @Environment(\.dismiss) private var dismiss
    @State private var setsByExercise: [String: [SetInputRow]] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let api = APIClient()

    var body: some View {
        NavigationStack {
            Form {
                ForEach(exercises) { exercise in
                    Section(exercise.name) {
                        ForEach(bindingRows(for: exercise).indices, id: \.self) { index in
                            setRow(exercise: exercise, index: index)
                        }
                        Button {
                            addSet(for: exercise)
                        } label: {
                            Label("Add Set", systemImage: "plus")
                        }
                    }
                }

                if let message = errorMessage {
                    Text(message).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Log Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                for exercise in exercises where setsByExercise[exercise.id] == nil {
                    setsByExercise[exercise.id] = [SetInputRow(setNumber: 1)]
                }
            }
        }
    }

    private func bindingRows(for exercise: Exercise) -> [SetInputRow] {
        setsByExercise[exercise.id] ?? []
    }

    private func addSet(for exercise: Exercise) {
        var rows = setsByExercise[exercise.id] ?? []
        rows.append(SetInputRow(setNumber: rows.count + 1))
        setsByExercise[exercise.id] = rows
    }

    @ViewBuilder
    private func setRow(exercise: Exercise, index: Int) -> some View {
        let binding = Binding<SetInputRow>(
            get: { setsByExercise[exercise.id]?[index] ?? SetInputRow(setNumber: index + 1) },
            set: { newValue in setsByExercise[exercise.id]?[index] = newValue }
        )

        HStack {
            Text("Set \(index + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            switch exercise.loggingType {
            case "reps_weight":
                TextField("Reps", text: binding.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                TextField("Weight (kg)", text: binding.weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            case "reps_only":
                TextField("Reps", text: binding.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            case "duration":
                TextField("Duration (sec)", text: binding.durationSeconds)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            case "distance":
                TextField("Distance (km)", text: binding.distance)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                TextField("Duration (sec)", text: binding.durationSeconds)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            default:
                TextField("Reps", text: binding.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func save() async {
        guard let token = AuthTokenStore.current else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let loggedAtString = DateFormatting.dateTime.string(from: combinedDateTime())

        do {
            for exercise in exercises {
                let rows = (setsByExercise[exercise.id] ?? []).filter { row in
                    !row.reps.isEmpty || !row.weight.isEmpty
                        || !row.durationSeconds.isEmpty || !row.distance.isEmpty
                }
                guard !rows.isEmpty else { continue }

                let sets = rows.map { row in
                    WorkoutSetPayload(
                        setNumber: row.setNumber,
                        reps: Int(row.reps),
                        weight: Double(row.weight),
                        weightUnit: row.weight.isEmpty ? nil : row.weightUnit,
                        durationSeconds: Int(row.durationSeconds),
                        distance: Double(row.distance),
                        distanceUnit: row.distance.isEmpty ? nil : row.distanceUnit
                    )
                }
                let payload = WorkoutLogCreatePayload(
                    exerciseId: exercise.id,
                    loggedAt: loggedAtString,
                    notes: nil,
                    sets: sets
                )
                _ = try await api.createWorkoutLog(payload, accessToken: token)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func combinedDateTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second
        return calendar.date(from: dateComponents) ?? date
    }
}
