import SwiftUI

enum FoodSource {
    case openFoodFacts(OpenFoodFactsProduct)
    case personalItem(FoodItem)
}

struct LogFoodQuantityView: View {
    let foodSource: FoodSource
    let mealType: String
    let date: Date
    var onLogged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quantity = "100"
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let api = APIClient()

    private var displayName: String {
        switch foodSource {
        case .openFoodFacts(let product): return product.name
        case .personalItem(let item): return item.name
        }
    }

    private var servingUnit: String {
        switch foodSource {
        case .openFoodFacts: return "g"
        case .personalItem(let item): return item.servingUnit
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    HStack {
                        Text("Quantity")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        TextField("Amount", text: $quantity)
                            .textFieldStyle(.themed)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text(servingUnit)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .cardStyle()

                if let message = errorMessage {
                    Text(message).foregroundStyle(Theme.danger).font(.footnote)
                }

                Spacer()
            }
            .padding(16)
            .background(Theme.background)
            .dismissKeyboardOnTap()
            .navigationTitle("Log Food")
            .darkNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await confirm() }
                    }
                    .disabled(Double(quantity) == nil || isSaving)
                }
            }
            .keyboardDismissButton()
        }
    }

    private func confirm() async {
        guard let token = AuthTokenStore.current, let quantityValue = Double(quantity) else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let foodItemId: String
            switch foodSource {
            case .personalItem(let item):
                foodItemId = item.id
            case .openFoodFacts(let product):
                // First sighting of this product - cache it into the
                // personal library, per the functional spec's grounding
                // rule (search results become personal library items,
                // not free-floating catalog entries).
                let created = try await api.createFoodItem(
                    product.asCreatePayload(), accessToken: token
                )
                foodItemId = created.id
            }

            let loggedAtString = DateFormatting.dateTime.string(from: combinedDateTime())
            let payload = NutritionLogCreatePayload(
                foodItemId: foodItemId,
                quantity: quantityValue,
                quantityUnit: servingUnit,
                mealType: mealType,
                loggedAt: loggedAtString
            )
            _ = try await api.createNutritionLog(payload, accessToken: token)
            onLogged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func combinedDateTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second
        return calendar.date(from: dateComponents) ?? date
    }
}
