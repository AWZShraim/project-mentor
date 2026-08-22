import Foundation
import Combine

@MainActor
final class NutritionViewModel: ObservableObject {
    static let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

    @Published var selectedDate = Date()
    @Published var entries: [NutritionLogRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient()

    func loadEntries() async {
        guard let token = AuthTokenStore.current else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let dateString = DateFormatting.dateOnly.string(from: selectedDate)
            entries = try await api.listNutritionLogs(date: dateString, accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        Task { await loadEntries() }
    }

    func goToNextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        Task { await loadEntries() }
    }

    func entries(for mealType: String) -> [NutritionLogRecord] {
        entries.filter { $0.mealType == mealType }
    }

    var totalCalories: Double { entries.reduce(0) { $0 + $1.calorieContribution } }
    var totalProtein: Double { entries.reduce(0) { $0 + $1.proteinContribution } }
    var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbsContribution } }
    var totalFat: Double { entries.reduce(0) { $0 + $1.fatContribution } }

    func removeEntry(_ entry: NutritionLogRecord) {
        entries.removeAll { $0.id == entry.id }
        guard let token = AuthTokenStore.current else { return }
        Task {
            try? await api.deleteNutritionLog(id: entry.id, accessToken: token)
        }
    }
}
