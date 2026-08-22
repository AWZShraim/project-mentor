import SwiftUI

struct NutritionView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("Nutrition")
                    .font(.title2.bold())
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Nutrition")
        }
    }
}

#Preview {
    NutritionView()
}
