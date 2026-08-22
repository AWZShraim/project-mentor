import SwiftUI

struct ExercisesView: View {
    @StateObject private var viewModel = ExercisesViewModel()
    @State private var showingDayPicker = false
    @State private var showingExercisePicker = false
    @State private var showingManageDays = false
    @State private var showingDatePicker = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    dateHeader
                    Divider()
                    content
                }

                manageDaysButton
                    .padding()
            }
            .navigationTitle("Exercises")
            .sheet(isPresented: $showingDayPicker) {
                TemplatePickerView { exercises in
                    viewModel.addExercises(exercises)
                    showingDayPicker = false
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercises in
                    viewModel.addExercises(exercises)
                    showingExercisePicker = false
                }
            }
            .sheet(isPresented: $showingManageDays) {
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
                                Task { await viewModel.loadEntries() }
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .task {
                await viewModel.loadEntries()
            }
        }
    }

    private var manageDaysButton: some View {
        Button {
            showingManageDays = true
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(radius: 4)
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
        } else {
            List {
                ForEach(viewModel.entries) { entry in
                    EditableExerciseRow(entry: entry, viewModel: viewModel)
                }

                Section {
                    actionButtons
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showingDayPicker = true
            } label: {
                Label("Add Day", systemImage: "calendar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showingExercisePicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
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

private struct EditableExerciseRow: View {
    @ObservedObject var entry: EditableWorkoutEntry
    let viewModel: ExercisesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.exercise.name).font(.headline)
                Spacer()
                unitPicker
                Button {
                    viewModel.removeEntry(entry)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            ForEach($entry.sets) { $row in
                setRow(row: $row)
            }

            Button {
                viewModel.addSet(to: entry)
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
        .onChange(of: entry.sets) { _, _ in
            viewModel.scheduleSave(for: entry)
        }
        .onChange(of: entry.weightUnit) { _, _ in
            viewModel.scheduleSave(for: entry)
        }
        .onChange(of: entry.distanceUnit) { _, _ in
            viewModel.scheduleSave(for: entry)
        }
    }

    @ViewBuilder
    private var unitPicker: some View {
        switch entry.exercise.loggingType {
        case "reps_weight":
            Picker("Unit", selection: $entry.weightUnit) {
                Text("lbs").tag("lbs")
                Text("kg").tag("kg")
            }
            .pickerStyle(.menu)
            .font(.caption)
        case "distance":
            Picker("Unit", selection: $entry.distanceUnit) {
                Text("mile").tag("mile")
                Text("km").tag("km")
            }
            .pickerStyle(.menu)
            .font(.caption)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func setRow(row: Binding<SetInputRow>) -> some View {
        HStack {
            Text("Set \(row.wrappedValue.setNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            switch entry.exercise.loggingType {
            case "reps_weight":
                TextField("Reps", text: row.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                TextField("Weight", text: row.weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            case "reps_only":
                TextField("Reps", text: row.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            case "duration":
                TextField("Seconds", text: row.durationSeconds)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            case "distance":
                TextField("Distance", text: row.distance)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                TextField("Seconds", text: row.durationSeconds)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            default:
                TextField("Reps", text: row.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            if entry.sets.count > 1 {
                Button {
                    viewModel.removeSet(id: row.wrappedValue.id, from: entry)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ExercisesView()
}
