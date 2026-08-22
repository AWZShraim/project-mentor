import Foundation
import Combine

@MainActor
final class ExercisesViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var logsForSelectedDate: [WorkoutLogEntryRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient()

    func loadLogs() async {
        guard let token = AuthTokenStore.current else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let dateString = DateFormatting.dateOnly.string(from: selectedDate)
            logsForSelectedDate = try await api.listWorkoutLogs(date: dateString, accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        Task { await loadLogs() }
    }

    func goToNextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        Task { await loadLogs() }
    }
}
