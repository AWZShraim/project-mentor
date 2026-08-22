import SwiftUI

struct ExercisesView: View {
    @StateObject private var viewModel = ExercisesViewModel()
    @State private var showingLogSheet = false
    @State private var showingTemplatesSheet = false
    @State private var showingDatePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateHeader
                Divider()
                content
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Splits") { showingTemplatesSheet = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLogSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet, onDismiss: {
                Task { await viewModel.loadLogs() }
            }) {
                LogWorkoutEntryView(date: viewModel.selectedDate)
            }
            .sheet(isPresented: $showingTemplatesSheet) {
                WorkoutTemplatesView()
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    DatePicker(
                        "Select date",
                        selection: $viewModel.selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("Select Date")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingDatePicker = false
                                Task { await viewModel.loadLogs() }
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .task {
                await viewModel.loadLogs()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if let message = viewModel.errorMessage {
            Spacer()
            Text(message).foregroundStyle(.red).font(.footnote).padding()
            Spacer()
        } else if viewModel.logsForSelectedDate.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "dumbbell")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Nothing logged for this day")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else {
            List(viewModel.logsForSelectedDate) { log in
                WorkoutLogRow(log: log)
            }
            .listStyle(.plain)
        }
    }

    private var dateHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousDay()
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Button {
                showingDatePicker = true
            } label: {
                Text(viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button {
                viewModel.goToNextDay()
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding()
    }
}

struct WorkoutLogRow: View {
    let log: WorkoutLogEntryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(log.exercise.name).font(.headline)
            ForEach(log.sets) { set in
                Text(setSummary(set))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func setSummary(_ set: WorkoutSetRecord) -> String {
        switch log.exercise.loggingType {
        case "reps_weight":
            let weight = set.weight.map { "\(formatted($0)) \(set.weightUnit ?? "kg")" } ?? "-"
            return "Set \(set.setNumber): \(set.reps ?? 0) reps @ \(weight)"
        case "reps_only":
            return "Set \(set.setNumber): \(set.reps ?? 0) reps"
        case "duration":
            return "Set \(set.setNumber): \(set.durationSeconds ?? 0)s"
        case "distance":
            let distance = set.distance.map { "\(formatted($0)) \(set.distanceUnit ?? "km")" } ?? "-"
            let duration = set.durationSeconds.map { " in \($0)s" } ?? ""
            return "Set \(set.setNumber): \(distance)\(duration)"
        default:
            return "Set \(set.setNumber)"
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

#Preview {
    ExercisesView()
}
