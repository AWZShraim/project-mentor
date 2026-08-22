import SwiftUI

struct CreateFoodItemView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    @State private var name = ""
    @State private var brand = ""
    @State private var servingSize = "100"
    @State private var servingUnit = "g"

    @State private var fiber = ""
    @State private var sugar = ""
    @State private var sodium = ""

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let api = APIClient()

    var body: some View {
        NavigationStack {
            Form {
                Section("Nutrition (per serving)") {
                    numberRow("Calories (kcal)", $calories)
                    numberRow("Protein (g)", $protein)
                    numberRow("Carbs (g)", $carbs)
                    numberRow("Fat (g)", $fat)
                }
                .listRowBackground(Theme.surface)

                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                }
                .listRowBackground(Theme.surface)

                Section("Serving Size") {
                    HStack {
                        TextField("Amount", text: $servingSize)
                            .keyboardType(.decimalPad)
                        TextField("Unit (g, ml, ...)", text: $servingUnit)
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Optional") {
                    numberRow("Fiber (g)", $fiber)
                    numberRow("Sugar (g)", $sugar)
                    numberRow("Sodium (mg)", $sodium)
                }
                .listRowBackground(Theme.surface)

                if let message = errorMessage {
                    Text(message).foregroundStyle(Theme.danger).font(.footnote)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("New Food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
        }
    }

    private func numberRow(_ label: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            TextField("0", text: text)
                .font(.stat(15, weight: .medium))
                .foregroundStyle(Theme.purple)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private var isValid: Bool {
        !name.isEmpty && Double(servingSize) != nil && !servingUnit.isEmpty
            && Double(calories) != nil && Double(protein) != nil
            && Double(carbs) != nil && Double(fat) != nil
    }

    private func save() async {
        guard let token = AuthTokenStore.current else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let payload = FoodItemCreatePayload(
                name: name,
                brand: brand.isEmpty ? nil : brand,
                sourceType: "manual",
                externalId: nil,
                servingSize: Double(servingSize) ?? 0,
                servingUnit: servingUnit,
                calories: Double(calories) ?? 0,
                proteinG: Double(protein) ?? 0,
                carbsG: Double(carbs) ?? 0,
                fatG: Double(fat) ?? 0,
                fiberG: Double(fiber),
                sugarG: Double(sugar),
                sodiumMg: Double(sodium)
            )
            _ = try await api.createFoodItem(payload, accessToken: token)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
