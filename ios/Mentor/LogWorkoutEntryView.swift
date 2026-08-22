import SwiftUI

/// Reached from the "+" button - goes straight to picking a saved split,
/// then to logging it. Logging individual exercises without a split lives
/// in AddExerciseFlowView instead, reached from the empty state.
struct LogWorkoutEntryView: View {
    let date: Date
    @State private var selectedExercises: [Exercise]?

    var body: some View {
        if let exercises = selectedExercises {
            WorkoutSetsFormView(date: date, exercises: exercises)
        } else {
            TemplatePickerView { exercises in
                selectedExercises = exercises
            }
        }
    }
}
