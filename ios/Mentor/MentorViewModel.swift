import Foundation
import Combine

@MainActor
final class MentorViewModel: ObservableObject {
    @Published var dashboard: DashboardRecord?
    @Published var messages: [ChatMessageRecord] = []
    @Published var pendingGoal: GoalRecord?
    @Published var pendingAction: AgentActionRecord?
    @Published var draftMessage = ""
    @Published var isLoadingDashboard = false
    @Published var isSendingMessage = false
    @Published var isLoggingWeight = false
    @Published var errorMessage: String?

    private let api = APIClient()

    func loadAll() async {
        async let dashboardTask: Void = loadDashboard()
        async let messagesTask: Void = loadMessages()
        async let goalsTask: Void = loadPendingGoal()
        async let actionsTask: Void = loadPendingAction()
        _ = await (dashboardTask, messagesTask, goalsTask, actionsTask)
    }

    func loadDashboard() async {
        guard let token = AuthTokenStore.current else { return }
        isLoadingDashboard = true
        defer { isLoadingDashboard = false }
        do {
            dashboard = try await api.mentorDashboard(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMessages() async {
        guard let token = AuthTokenStore.current else { return }
        do {
            messages = try await api.listMentorMessages(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPendingGoal() async {
        guard let token = AuthTokenStore.current else { return }
        do {
            let goals = try await api.listGoals(accessToken: token)
            pendingGoal = goals.first { $0.status == "proposed" }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPendingAction() async {
        guard let token = AuthTokenStore.current else { return }
        do {
            let actions = try await api.listAgentActions(accessToken: token)
            pendingAction = actions.first { $0.status == "proposed" }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendMessage() async {
        let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let token = AuthTokenStore.current else { return }
        draftMessage = ""
        errorMessage = nil

        messages.append(
            ChatMessageRecord(
                id: UUID().uuidString, role: "user", content: text,
                createdAt: DateFormatting.dateTime.string(from: Date())
            )
        )

        isSendingMessage = true
        defer { isSendingMessage = false }
        do {
            let result = try await api.sendMentorChat(message: text, accessToken: token)
            messages.append(
                ChatMessageRecord(
                    id: UUID().uuidString, role: "assistant", content: result.reply,
                    createdAt: DateFormatting.dateTime.string(from: Date())
                )
            )
            if let goal = result.proposedGoal {
                pendingGoal = goal
            }
            if let action = result.proposedAction {
                pendingAction = action
            }
            await loadDashboard()
        } catch APIError.server(503, _) {
            errorMessage = "Mentor isn't set up yet - it needs an Anthropic API key on the backend."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approveGoal(_ goal: GoalRecord) async {
        guard let token = AuthTokenStore.current else { return }
        do {
            _ = try await api.approveGoal(id: goal.id, accessToken: token)
            pendingGoal = nil
            await loadDashboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectGoal(_ goal: GoalRecord) async {
        guard let token = AuthTokenStore.current else { return }
        do {
            _ = try await api.rejectGoal(id: goal.id, accessToken: token)
            pendingGoal = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approveAction(_ action: AgentActionRecord) async {
        guard let token = AuthTokenStore.current else { return }
        do {
            _ = try await api.approveAgentAction(id: action.id, accessToken: token)
            pendingAction = nil
            await loadDashboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectAction(_ action: AgentActionRecord) async {
        guard let token = AuthTokenStore.current else { return }
        do {
            _ = try await api.rejectAgentAction(id: action.id, accessToken: token)
            pendingAction = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logWeight(_ value: Double, unit: String) async {
        guard let token = AuthTokenStore.current else { return }
        isLoggingWeight = true
        defer { isLoggingWeight = false }
        do {
            let payload = HealthMetricCreatePayload(
                metricType: "weight",
                value: value,
                unit: unit,
                recordedAt: DateFormatting.dateTime.string(from: Date())
            )
            _ = try await api.logHealthMetric(payload, accessToken: token)
            await loadDashboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
