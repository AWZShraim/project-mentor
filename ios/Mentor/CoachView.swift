import SwiftUI

struct CoachView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("AI Coach")
                    .font(.title2.bold())
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Coach")
        }
    }
}

#Preview {
    CoachView()
}
