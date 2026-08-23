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
                    ScreenTitle(title: "Exercises")
                    dateHeader
                    Divider().overlay(Theme.border)
                    content
                }
                .background(Theme.background)

                manageDaysButton
                    .padding(.trailing, 16)
                    .padding(.bottom, 96)
            }
            .hiddenNavBar()
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
                    .tint(Theme.purple)
                    .padding()
                    .background(Theme.background)
                    .navigationTitle("Select Date")
                    .darkNavBar()
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
                .foregroundStyle(Theme.background)
                .frame(width: 52, height: 52)
                .background(Theme.purple)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Theme.purple.opacity(0.5), radius: 10)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView().tint(Theme.purple)
            Spacer()
        } else if let message = viewModel.errorMessage {
            Spacer()
            Text(message).foregroundStyle(Theme.danger).font(.footnote).padding()
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(viewModel.entries) { entry in
                        EditableExerciseRow(entry: entry, viewModel: viewModel)
                    }

                    actionButtons
                }
                .padding(16)
            }
            .tabBarSafeArea()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                showingDayPicker = true
            } label: {
                Label("Add Day", systemImage: "calendar")
            }
            .buttonStyle(.mentorPrimary)

            Button {
                showingExercisePicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
            }
            .buttonStyle(.mentorSecondary)
        }
        .padding(.top, 4)
    }

    private var dateHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousDay()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Theme.purple)
            }

            Spacer()

            Button {
                showingDatePicker = true
            } label: {
                Text(viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer()

            Button {
                viewModel.goToNextDay()
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.purple)
            }
        }
        .padding()
    }
}

private struct EditableExerciseRow: View {
    @ObservedObject var entry: EditableWorkoutEntry
    let viewModel: ExercisesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                unitPicker
                Button {
                    viewModel.removeEntry(entry)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.danger)
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.blue)
            }
        }
        .cardStyle()
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
            .tint(Theme.blue)
        case "distance":
            Picker("Unit", selection: $entry.distanceUnit) {
                Text("mile").tag("mile")
                Text("km").tag("km")
            }
            .pickerStyle(.menu)
            .font(.caption)
            .tint(Theme.blue)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func setRow(row: Binding<SetInputRow>) -> some View {
        HStack(spacing: 8) {
            Text("Set \(row.wrappedValue.setNumber)")
                .font(.stat(11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 40, alignment: .leading)

            switch entry.exercise.loggingType {
            case "reps_weight":
                TextField("Reps", text: row.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.themed)
                TextField("Weight", text: row.weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.themed)
            case "reps_only":
                TextField("Reps", text: row.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.themed)
            case "duration":
                TextField("Seconds", text: row.durationSeconds)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.themed)
            case "distance":
                TextField("Distance", text: row.distance)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.themed)
                TextField("Seconds", text: row.durationSeconds)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.themed)
            default:
                TextField("Reps", text: row.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.themed)
            }

            if entry.sets.count > 1 {
                Button {
                    viewModel.removeSet(id: row.wrappedValue.id, from: entry)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ExercisesView()
}
