import SwiftUI

struct MainTabView: View {
    @ObservedObject var auth: AuthViewModel

    var body: some View {
        TabView {
            CoachView()
                .tabItem {
                    Label("Coach", systemImage: "sparkles")
                }

            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }

            ExercisesView()
                .tabItem {
                    Label("Exercises", systemImage: "dumbbell.fill")
                }

            SettingsView(auth: auth)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}
