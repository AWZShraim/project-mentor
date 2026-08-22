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
                .padding()

                if selectedTab == 0 {
                    OpenFoodFactsSearchView(mealType: mealType, date: date, onLogged: { dismiss() })
                } else {
                    PersonalLibraryView(mealType: mealType, date: date, onLogged: { dismiss() })
                }
            }
            .background(Theme.background)
            .navigationTitle("Add Food")
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

    private let offService = OpenFoodFactsService()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search foods", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await search() } }
                Button("Search") { Task { await search() } }
                    .tint(Theme.purple)
                    .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if isSearching {
                Spacer()
                ProgressView()
                Spacer()
            } else if let message = errorMessage {
                Spacer()
                Text(message).foregroundStyle(Theme.danger).font(.footnote).padding()
                Spacer()
            } else if results.isEmpty {
                Spacer()
                Text("Search Open Food Facts for packaged foods")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List(results) { product in
                    Button {
                        selectedProduct = product
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name).foregroundStyle(Theme.textPrimary)
                            Text("\(Int(product.caloriesPer100g)) kcal / 100g" + (product.brand.map { " \u{00B7} \($0)" } ?? ""))
                                .font(.stat(11, weight: .medium))
                                .foregroundStyle(Theme.purpleSoft)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
                .background(Theme.background)
                .listStyle(.plain)
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

    private func search() async {
        let term = searchText.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let found = try await offService.search(term: term)
            results = found.sorted {
                relevanceRank($0.name, matching: term) < relevanceRank($1.name, matching: term)
            }
        } catch {
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
                ProgressView()
            } else {
                List {
                    if searchText.isEmpty && !recentItems.isEmpty {
                        Section("Recent") {
                            ForEach(recentItems) { item in
                                foodRow(item)
                            }
                        }
                        .listRowBackground(Theme.surface)
                    }

                    Section(searchText.isEmpty ? "All Foods" : "Results") {
                        ForEach(filteredItems) { item in
                            foodRow(item)
                        }
                    }
                    .listRowBackground(Theme.surface)

                    Section {
                        Button {
                            showingCreate = true
                        } label: {
                            Label("Create New Food", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.purple)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    if let message = errorMessage {
                        Text(message).foregroundStyle(Theme.danger).font(.footnote)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.background)
                .listStyle(.plain)
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
                Text(item.name).foregroundStyle(Theme.textPrimary)
                Text("\(Int(item.calories)) kcal / \(formattedNumber(item.servingSize))\(item.servingUnit)")
                    .font(.stat(11, weight: .medium))
                    .foregroundStyle(Theme.purpleSoft)
            }
        }
        .buttonStyle(.plain)
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
