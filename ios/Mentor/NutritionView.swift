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
                Divider()
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
                    .padding()
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
            ProgressView()
            Spacer()
        } else if let message = viewModel.errorMessage {
            Spacer()
            Text(message).foregroundStyle(Theme.danger).font(.footnote).padding()
            Spacer()
        } else {
            List {
                dailyTotalsSection

                ForEach(NutritionViewModel.mealTypes, id: \.self) { mealType in
                    mealSection(mealType)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .listStyle(.insetGrouped)
        }
    }

    private var dailyTotalsSection: some View {
        Section {
            VStack(spacing: 10) {
                Text("\(Int(viewModel.totalCalories))")
                    .font(.stat(30))
                    .foregroundStyle(Theme.purple)
                    .shadow(color: Theme.purple.opacity(0.5), radius: 10)
                Text("kcal today")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 10) {
                    macroChip("Protein", viewModel.totalProtein)
                    macroChip("Carbs", viewModel.totalCarbs)
                    macroChip("Fat", viewModel.totalFat)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .listRowBackground(Theme.surface)
        }
    }

    private func macroChip(_ name: String, _ grams: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(grams))g")
                .font(.stat(13))
                .foregroundStyle(Theme.blue)
            Text(name)
                .font(.system(size: 9, weight: .medium))
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Theme.blueBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func mealSection(_ mealType: String) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedMeals.contains(mealType) },
                set: { isExpanded in
                    if isExpanded {
                        expandedMeals.insert(mealType)
                    } else {
                        expandedMeals.remove(mealType)
                    }
                }
            )
        ) {
            let mealEntries = viewModel.entries(for: mealType)

            ForEach(mealEntries) { entry in
                NutritionLogRow(entry: entry)
            }
            .onDelete { offsets in
                for index in offsets {
                    viewModel.removeEntry(mealEntries[index])
                }
            }

            Button {
                addingMealType = mealType
            } label: {
                Label("Add Food", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(Theme.purple)
            }
        } label: {
            Text(mealType.capitalized)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
        }
        .listRowBackground(Theme.surface)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.foodItem.name)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
            Text("\(formattedNumber(entry.quantity))\(entry.quantityUnit) \u{00B7} \(Int(entry.calorieContribution)) kcal")
                .font(.stat(11, weight: .medium))
                .foregroundStyle(Theme.purpleSoft)
        }
    }
}

#Preview {
    NutritionView()
}
