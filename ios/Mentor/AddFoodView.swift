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
                Text(message).foregroundStyle(.red).font(.footnote).padding()
                Spacer()
            } else if results.isEmpty {
                Spacer()
                Text("Search Open Food Facts for packaged foods")
                    .foregroundStyle(.secondary)
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
                            Text(product.name).foregroundStyle(.primary)
                            Text("\(Int(product.caloriesPer100g)) kcal / 100g" + (product.brand.map { " \u{00B7} \($0)" } ?? ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
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
            results = try await offService.search(term: term)
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
                    ForEach(filteredItems) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).foregroundStyle(.primary)
                                Text("\(Int(item.calories)) kcal / \(formattedNumber(item.servingSize))\(item.servingUnit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Section {
                        Button {
                            showingCreate = true
                        } label: {
                            Label("Create New Food", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .listRowSeparator(.hidden)

                    if let message = errorMessage {
                        Text(message).foregroundStyle(.red).font(.footnote)
                    }
                }
                .listStyle(.plain)
            }
        }
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

    private var filteredItems: [FoodItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func load() async {
        guard let token = AuthTokenStore.current else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await api.listFoodItems(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
