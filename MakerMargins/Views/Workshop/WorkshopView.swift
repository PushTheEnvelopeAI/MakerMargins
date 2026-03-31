// WorkshopView.swift
// MakerMargins
//
// Tab 2 root — the shared work step library.
// Displays all WorkSteps across all products, searchable by title.
// Each row shows step title, product usage count, and hours per unit.
// Tapping a row pushes WorkStepDetailView for quick stopwatch access.
// Steps can also be created here as standalone library entries (no product link).

import SwiftUI
import SwiftData

struct WorkshopView: View {
    @Query(sort: \WorkStep.title) private var allSteps: [WorkStep]
    @Environment(\.currencyFormatter) private var formatter

    @State private var searchText = ""
    @State private var showingCreateForm = false

    // MARK: - Computed

    private var filteredSteps: [WorkStep] {
        if searchText.isEmpty {
            return allSteps
        }
        return allSteps.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if allSteps.isEmpty {
                ContentUnavailableView(
                    "No Work Steps",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Tap + to create a step, or add steps from a product's detail view.")
                )
            } else if filteredSteps.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                stepList
            }
        }
        .navigationTitle("Labor")
        .searchable(text: $searchText, prompt: "Search steps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: WorkStep.self) { step in
            WorkStepDetailView(step: step)
        }
        .sheet(isPresented: $showingCreateForm) {
            WorkStepFormView(step: nil, product: nil)
        }
    }

    // MARK: - Step List

    private var stepList: some View {
        List(filteredSteps, id: \.persistentModelID) { step in
            NavigationLink(value: step) {
                HStack(spacing: AppTheme.Spacing.md) {
                    WorkStepThumbnailView(imageData: step.image)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(step.title)
                            .font(AppTheme.Typography.rowTitle)
                            .lineLimit(1)

                        HStack(spacing: AppTheme.Spacing.sm) {
                            Text(UsageText.from(products: step.productWorkSteps.compactMap(\.product)))
                                .font(AppTheme.Typography.rowCaption)
                                .foregroundStyle(.secondary)

                            Text("·")
                                .foregroundStyle(.tertiary)

                            Text("\(CostingEngine.formatHours(CostingEngine.unitTimeHours(step: step))) hrs/\(step.unitName)")
                                .font(AppTheme.Typography.rowCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
    }
}
