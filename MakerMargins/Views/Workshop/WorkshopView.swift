// WorkshopView.swift
// MakerMargins
//
// Tab 2 root — the shared work step library.
// Displays all WorkSteps across all products, searchable by title.
// Each row shows step title, product usage count, and hours per unit.
// Tapping a row pushes WorkStepDetailView for quick stopwatch access.
// Steps can also be created here as standalone library entries (no product link).
// Supports multi-select deletion via Edit mode.

import SwiftUI
import SwiftData

struct WorkshopView: View {
    @Query(sort: \WorkStep.title) private var allSteps: [WorkStep]
    @Environment(\.currencyFormatter) private var formatter
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var showingCreateForm = false
    @State private var navigationPath = NavigationPath()
    @State private var stepCountBeforeSheet = 0
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<WorkStep.ID>()
    @State private var showingDeleteConfirmation = false

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
        NavigationStack(path: $navigationPath) {
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
                        stepCountBeforeSheet = allSteps.count
                        showingCreateForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create work step")
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !allSteps.isEmpty {
                        EditButton()
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .onChange(of: editMode) { _, newValue in
                if !newValue.isEditing { selection.removeAll() }
            }
            .navigationDestination(for: WorkStep.self) { step in
                WorkStepDetailView(step: step)
            }
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
            .sheet(isPresented: $showingCreateForm, onDismiss: {
                if allSteps.count > stepCountBeforeSheet,
                   let newStep = allSteps.last {
                    navigationPath.append(newStep)
                }
            }) {
                WorkStepFormView(step: nil, product: nil)
            }
            .confirmationDialog(
                "Delete \(selection.count) Step\(selection.count == 1 ? "" : "s")?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(selection.count) Step\(selection.count == 1 ? "" : "s")", role: .destructive) {
                    deleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the selected step\(selection.count == 1 ? "" : "s") and remove \(selection.count == 1 ? "it" : "them") from all products. This action cannot be undone.")
            }
        }
    }

    // MARK: - Step List

    private var stepList: some View {
        List(filteredSteps, id: \.persistentModelID, selection: $selection) { step in
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
        .safeAreaInset(edge: .bottom) {
            if editMode.isEditing && !selection.isEmpty {
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Text("Delete \(selection.count) Step\(selection.count == 1 ? "" : "s")")
                        .font(AppTheme.Typography.sectionHeader)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(AppTheme.Colors.destructive, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Actions

    private func deleteSelected() {
        let stepsToDelete = allSteps.filter { selection.contains($0.persistentModelID) }
        for step in stepsToDelete {
            modelContext.delete(step)
        }
        selection.removeAll()
        editMode = .inactive
    }
}
