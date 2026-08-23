import SwiftUI

struct NutritionView: View {
    @StateObject private var viewModel = NutritionViewModel()
    @State private var showingDatePicker = false
    @State private var addingMealType: String?
    @State private var expandedMeals: Set<String> = Set(NutritionViewModel.mealTypes)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateHeader
                Divider().overlay(Theme.border)
                content
            }
            .background(Theme.background)
            .navigationTitle("Nutrition")
            .sheet(isPresented: Binding(
                get: { addingMealType != nil },
                set: { if !$0 { addingMealType = nil } }
            ), onDismiss: {
                Task { await viewModel.loadEntries() }
            }) {
                if let mealType = addingMealType {
                    AddFoodView(mealType: mealType, date: viewModel.selectedDate)
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    DatePicker(
                        "Select date",
                        selection: $viewModel.selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Theme.purple)
                    .padding()
                    .background(Theme.background)
                    .navigationTitle("Select Date")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingDatePicker = false
                                Task { await viewModel.loadEntries() }
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .task {
                await viewModel.loadEntries()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView().tint(Theme.purple)
            Spacer()
        } else if let message = viewModel.errorMessage {
            Spacer()
            Text(message).foregroundStyle(Theme.danger).font(.footnote).padding()
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    dailyTotalsCard

                    ForEach(NutritionViewModel.mealTypes, id: \.self) { mealType in
                        mealCard(mealType)
                    }
                }
                .padding(16)
            }
        }
    }

    private var dailyTotalsCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("\(Int(viewModel.totalCalories))")
                    .font(.stat(32))
                    .foregroundStyle(Theme.purple)
                    .shadow(color: Theme.purple.opacity(0.5), radius: 10)
                Text("kcal today")
                    .font(.system(size: 11, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 10) {
                MacroChip(label: "Protein", value: "\(Int(viewModel.totalProtein))g")
                MacroChip(label: "Carbs", value: "\(Int(viewModel.totalCarbs))g")
                MacroChip(label: "Fat", value: "\(Int(viewModel.totalFat))g")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .cardStyle()
    }

    private func mealCard(_ mealType: String) -> some View {
        let mealEntries = viewModel.entries(for: mealType)
        let isExpanded = expandedMeals.contains(mealType)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedMeals.remove(mealType)
                    } else {
                        expandedMeals.insert(mealType)
                    }
                }
            } label: {
                HStack {
                    Text(mealType.capitalized)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if mealEntries.isEmpty {
                        Text("Nothing logged")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 12)
                    } else {
                        ForEach(mealEntries) { entry in
                            NutritionLogRow(entry: entry) {
                                viewModel.removeEntry(entry)
                            }
                        }
                    }

                    Button {
                        addingMealType = mealType
                    } label: {
                        Label("Add Food", systemImage: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.purple)
                    }
                    .padding(.top, 2)
                }
                .padding(.top, 12)
            }
        }
        .cardStyle()
    }

    private var dateHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousDay()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Theme.purple)
            }

            Spacer()

            Button {
                showingDatePicker = true
            } label: {
                Text(viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer()

            Button {
                viewModel.goToNextDay()
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.purple)
            }
        }
        .padding()
    }
}

private struct NutritionLogRow: View {
    let entry: NutritionLogRecord
    var onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodItem.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(formattedNumber(entry.quantity))\(entry.quantityUnit) \u{00B7} \(Int(entry.calorieContribution)) kcal")
                    .font(.stat(11, weight: .medium))
                    .foregroundStyle(Theme.purpleSoft)
            }
            Spacer()
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NutritionView()
}
