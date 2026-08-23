import SwiftUI

struct TemplatePickerView: View {
    var onSelect: ([Exercise]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var templates: [WorkoutTemplate] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let api = APIClient()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(Theme.purple)
                } else if let message = errorMessage {
                    Text(message).foregroundStyle(Theme.danger).padding()
                } else if templates.isEmpty {
                    ScrollView {
                        EmptyStateCard(
                            icon: "calendar",
                            title: "No days yet",
                            message: "Create one from the Days screen first"
                        )
                        .padding(16)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(templates) { template in
                                Button {
                                    onSelect(template.exercises)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                        Text("\(template.exercises.count) exercises")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .cardStyle()
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Choose a Day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await load()
            }
        }
    }

    private func load() async {
        guard let token = AuthTokenStore.current else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            templates = try await api.listTemplates(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
