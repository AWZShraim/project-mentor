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
                    ProgressView()
                } else if let message = errorMessage {
                    Text(message).foregroundStyle(Theme.danger).padding()
                } else if templates.isEmpty {
                    ContentUnavailableView(
                        "No days yet",
                        systemImage: "calendar",
                        description: Text("Create one from the Days screen first")
                    )
                } else {
                    List(templates) { template in
                        Button {
                            onSelect(template.exercises)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(template.exercises.count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.surface)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Theme.background)
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
