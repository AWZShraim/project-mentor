import SwiftUI

struct MentorView: View {
    @StateObject private var viewModel = MentorViewModel()
    @State private var showingWeightEntry = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenTitle(title: "Mentor")

                dashboardSection
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)

                Divider().overlay(Theme.border)

                chatSection
            }
            .tabBarSafeArea()
            .background(AmbientBackground())
            .hiddenNavBar()
            .sheet(isPresented: $showingWeightEntry) {
                WeightEntrySheet { value, unit in
                    Task { await viewModel.logWeight(value, unit: unit) }
                }
            }
            .task {
                await viewModel.loadAll()
            }
        }
    }

    // MARK: - Top half: dashboard

    private var dashboardSection: some View {
        VStack(spacing: 10) {
            insightCard

            HStack(spacing: 10) {
                DashboardTile(
                    value: viewModel.dashboard.map { Int($0.todayCalories).formatted() } ?? "--",
                    label: "kcal today",
                    subtitle: viewModel.dashboard?.activeGoal.map { "goal \($0.value.dailyCalories)" }
                )
                DashboardTile(
                    value: weightValueText,
                    label: "weight",
                    subtitle: weightSubtitle,
                    accent: Theme.blue
                ) {
                    showingWeightEntry = true
                }
                DashboardTile(
                    value: sleepValueText,
                    label: "sleep",
                    subtitle: viewModel.dashboard?.sleepHoursLastNight == nil ? "not connected" : nil,
                    accent: Theme.purpleSoft
                )
            }

            if let dashboard = viewModel.dashboard {
                HStack(spacing: 10) {
                    MacroChip(label: "Protein", value: "\(Int(dashboard.todayProteinG))g")
                    MacroChip(label: "Carbs", value: "\(Int(dashboard.todayCarbsG))g")
                    MacroChip(label: "Fat", value: "\(Int(dashboard.todayFatG))g")
                }
            }
        }
    }

    private var insightCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.purple)
                .neonGlow(Theme.purple, radius: 10)

            if viewModel.isLoadingDashboard && viewModel.dashboard == nil {
                ProgressView().tint(Theme.purple)
            } else {
                Text(viewModel.dashboard?.insightText ?? "Log some data to get insights.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14, glow: true)
    }

    private var weightValueText: String {
        guard let weight = viewModel.dashboard?.latestWeight else { return "--" }
        return formattedNumber(weight.value)
    }

    private var weightSubtitle: String? {
        guard let change = viewModel.dashboard?.weightChange7d else { return nil }
        let sign = change > 0 ? "+" : ""
        return "\(sign)\(formattedNumber(change)) (7d)"
    }

    private var sleepValueText: String {
        guard let hours = viewModel.dashboard?.sleepHoursLastNight else { return "--" }
        return "\(formattedNumber(hours))h"
    }

    // MARK: - Bottom half: chat

    private var chatSection: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                        }

                        if let goal = viewModel.pendingGoal {
                            ProposalCard(
                                title: "Proposed nutrition target",
                                summary: "\(goal.value.dailyCalories) kcal \u{00B7} \(goal.value.proteinG)P / \(goal.value.carbsG)C / \(goal.value.fatG)F",
                                reasoning: goal.reasoning,
                                onApprove: { Task { await viewModel.approveGoal(goal) } },
                                onReject: { Task { await viewModel.rejectGoal(goal) } }
                            )
                        }

                        if let action = viewModel.pendingAction {
                            ProposalCard(
                                title: "Proposed action",
                                summary: action.summary,
                                reasoning: action.reasoning,
                                onApprove: { Task { await viewModel.approveAction(action) } },
                                onReject: { Task { await viewModel.rejectAction(action) } }
                            )
                        }

                        if viewModel.isSendingMessage {
                            HStack(spacing: 8) {
                                ProgressView().tint(Theme.purple)
                                Text("Mentor is thinking\u{2026}")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }

                        if let message = viewModel.errorMessage {
                            Text(message).foregroundStyle(Theme.danger).font(.footnote)
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(16)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            inputBar
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask Mentor, or tell it what you did\u{2026}", text: $viewModel.draftMessage, axis: .vertical)
                .textFieldStyle(.themed)
                .lineLimit(1...4)

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Theme.textSecondary
                            : Theme.purple
                    )
            }
            .disabled(
                viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isSendingMessage
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.background)
    }
}

private struct DashboardTile: View {
    let value: String
    let label: String
    var subtitle: String?
    var accent: Color = Theme.purple
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(value)
                    .font(.stat(20, weight: .heavy))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Theme.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .cardStyle(padding: 8)
    }
}

private struct ChatBubble: View {
    let message: ChatMessageRecord

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(message.content)
                .font(.system(size: 14))
                .foregroundStyle(isUser ? Theme.background : Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Theme.purple : Theme.surfaceElevated.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

private struct ProposalCard: View {
    let title: String
    let summary: String
    let reasoning: String?
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.purple)
            Text(summary)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            if let reasoning {
                Text(reasoning)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 10) {
                Button("Approve", action: onApprove)
                    .buttonStyle(.mentorPrimary)
                Button("Dismiss", action: onReject)
                    .buttonStyle(.mentorSecondary(tint: Theme.danger))
            }
        }
        .cardStyle(glow: true)
    }
}

private struct WeightEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""
    @State private var unit = "lbs"
    var onSave: (Double, String) -> Void

    private var parsedWeight: Double? { Double(weightText) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                TextField("Weight", text: $weightText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.themed)

                Picker("Unit", selection: $unit) {
                    Text("lbs").tag("lbs")
                    Text("kg").tag("kg")
                }
                .pickerStyle(.segmented)
                .tint(Theme.purple)

                Button("Log Weight") {
                    guard let value = parsedWeight else { return }
                    onSave(value, unit)
                    dismiss()
                }
                .buttonStyle(.mentorPrimary)
                .disabled(parsedWeight == nil)

                Spacer()
            }
            .padding(18)
            .background(Theme.background)
            .navigationTitle("Log Weight")
            .darkNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}

#Preview {
    MentorView()
}
