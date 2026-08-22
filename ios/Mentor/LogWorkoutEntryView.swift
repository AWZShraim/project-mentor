import SwiftUI

struct LogWorkoutEntryView: View {
    let date: Date

    @State private var selectedExercises: [Exercise] = []
    @State private var showingExercisePicker = false
    @State private var showingTemplatePicker = false

    var body: some View {
        if selectedExercises.isEmpty {
            NavigationStack {
                VStack(spacing: 20) {
                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label("Choose a Split", systemImage: "list.bullet.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Log Freeform", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
                .padding()
                .navigationTitle("Log Workout")
                .sheet(isPresented: $showingExercisePicker) {
                    ExercisePickerView { exercises in
                        selectedExercises = exercises
                        showingExercisePicker = false
                    }
                }
                .sheet(isPresented: $showingTemplatePicker) {
                    TemplatePickerView { exercises in
                        selectedExercises = exercises
                        showingTemplatePicker = false
                    }
                }
            }
        } else {
            WorkoutSetsFormView(date: date, exercises: selectedExercises)
        }
    }
}
