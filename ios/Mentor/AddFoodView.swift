import SwiftUI

struct AddFoodView: View {
    let mealType: String
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Source", selection: $selectedTab) {
                    Text("Search").tag(0)
                    Text("My Library").tag(1)
                }
                .pickerStyle(.segmented)
                .tint(Theme.purple)
                .padding()

                if selectedTab == 0 {
                    OpenFoodFactsSearchView(mealType: mealType, date: date, onLogged: { dismiss() })
                } else {
                    PersonalLibraryView(mealType: mealType, date: date, onLogged: { dismiss() })
                }
            }
            .background(Theme.background)
            .navigationTitle("Add Food")
            .darkNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct OpenFoodFactsSearchView: View {
    let mealType: String
    let date: Date
    var onLogged: () -> Void

    @State private var searchText = ""
    @State private var results: [OpenFoodFactsProduct] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var selectedProduct: OpenFoodFactsProduct?
    @State private var searchTask: Task<Void, Never>?

    private let offService = OpenFoodFactsService()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search foods", text: $searchText)
                    .textFieldStyle(.themed)
                    .onChange(of: searchText) { _, newValue in
                        scheduleSearch(for: newValue)
                    }
                if isSearching {
                    ProgressView().tint(Theme.purple)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if let message = errorMessage {
                Spacer()
                Text(message).foregroundStyle(Theme.danger).font(.footnote).padding()
                Spacer()
            } else if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                Spacer()
                Text("Search Open Food Facts for packaged foods")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else if results.isEmpty {
                Spacer()
                if isSearching {
                    ProgressView().tint(Theme.purple)
                } else {
                    Text("No results for \u{201C}\(searchText)\u{201D}")
                        .foregroundStyle(Theme.textSecondary)
                        .font(.footnote)
                        .padding()
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(results) { product in
                            Button {
                                selectedProduct = product
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.name)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("\(Int(product.caloriesPer100g)) kcal / 100g" + (product.brand.map { " \u{00B7} \($0)" } ?? ""))
                                        .font(.stat(11, weight: .medium))
                                        .foregroundStyle(Theme.purpleSoft)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .cardStyle(padding: 12)
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Theme.background)
        .sheet(item: $selectedProduct) { product in
            LogFoodQuantityView(
                foodSource: .openFoodFacts(product),
                mealType: mealType,
                date: date,
                onLogged: onLogged
            )
        }
    }

    /// Debounces as-you-type search: cancels any pending search and
    /// reschedules, so a fast typer doesn't fire a network request per
    /// keystroke. Empties results immediately on an empty query rather
    /// than waiting out the debounce.
    private func scheduleSearch(for term: String) {
        searchTask?.cancel()
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search(term: trimmed)
        }
    }

    private func search(term: String) async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let found = try await offService.search(term: term)
            guard !Task.isCancelled else { return }
            results = found.sorted {
                relevanceRank($0.name, matching: term) < relevanceRank($1.name, matching: term)
            }
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}

private struct PersonalLibraryView: View {
    let mealType: String
    let date: Date
    var onLogged: () -> Void

    @State private var items: [FoodItem] = []
    @State private var recentItems: [FoodItem] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedItem: FoodItem?
    @State private var showingCreate = false

    private let api = APIClient()

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(Theme.purple)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if searchText.isEmpty && !recentItems.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader("Recent")
                                ForEach(recentItems) { item in
                                    foodRow(item)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(searchText.isEmpty ? "All Foods" : "Results")
                            ForEach(filteredItems) { item in
                                foodRow(item)
                            }
                        }

                        Button {
                            showingCreate = true
                        } label: {
                            Label("Create New Food", systemImage: "plus")
                        }
                        .buttonStyle(.mentorPrimary)

                        if let message = errorMessage {
                            Text(message).foregroundStyle(Theme.danger).font(.footnote)
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Theme.background)
        .searchable(text: $searchText, prompt: "Search your foods")
        .sheet(item: $selectedItem) { item in
            LogFoodQuantityView(
                foodSource: .personalItem(item),
                mealType: mealType,
                date: date,
                onLogged: onLogged
            )
        }
        .sheet(isPresented: $showingCreate, onDismiss: {
            Task { await load() }
        }) {
            CreateFoodItemView()
        }
        .task {
            await load()
        }
    }

    private func foodRow(_ item: FoodItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(Int(item.calories)) kcal / \(formattedNumber(item.servingSize))\(item.servingUnit)")
                    .font(.stat(11, weight: .medium))
                    .foregroundStyle(Theme.purpleSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .cardStyle(padding: 12)
    }

    private var filteredItems: [FoodItem] {
        guard !searchText.isEmpty else { return items }
        return items
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { relevanceRank($0.name, matching: searchText) < relevanceRank($1.name, matching: searchText) }
    }

    private func load() async {
        guard let token = AuthTokenStore.current else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let itemsTask = api.listFoodItems(accessToken: token)
            async let recentTask = api.listRecentFoodItems(accessToken: token)
            items = try await itemsTask
            recentItems = try await recentTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
