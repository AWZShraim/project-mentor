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
            Text(message).foregroundStyle(.red).font(.footnote).padding()
            Spacer()
        } else {
            List {
                dailyTotalsSection

                ForEach(NutritionViewModel.mealTypes, id: \.self) { mealType in
                    mealSection(mealType)
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var dailyTotalsSection: some View {
        Section {
            VStack(spacing: 8) {
                Text("\(Int(viewModel.totalCalories)) kcal")
                    .font(.title2.bold())
                HStack(spacing: 16) {
                    macroLabel("Protein", viewModel.totalProtein)
                    macroLabel("Carbs", viewModel.totalCarbs)
                    macroLabel("Fat", viewModel.totalFat)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func macroLabel(_ name: String, _ grams: Double) -> some View {
        VStack {
            Text("\(Int(grams))g").font(.headline)
            Text(name).font(.caption).foregroundStyle(.secondary)
        }
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
            }
        } label: {
            Text(mealType.capitalized).font(.headline)
        }
    }

    private var dateHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousDay()
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Button {
                showingDatePicker = true
            } label: {
                Text(viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button {
                viewModel.goToNextDay()
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding()
    }
}

private struct NutritionLogRow: View {
    let entry: NutritionLogRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.foodItem.name).font(.body)
            Text("\(formattedNumber(entry.quantity))\(entry.quantityUnit) \u{00B7} \(Int(entry.calorieContribution)) kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NutritionView()
}
