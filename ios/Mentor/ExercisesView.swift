import SwiftUI

struct ExercisesView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("Exercises")
                    .font(.title2.bold())
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Exercises")
        }
    }
}

#Preview {
    ExercisesView()
}
