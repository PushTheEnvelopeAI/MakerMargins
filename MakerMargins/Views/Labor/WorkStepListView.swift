// WorkStepListView.swift
// MakerMargins
//
// Inline component embedded in ProductDetailView.
// Displays a product's work steps sorted by sortOrder, with add (new or existing),
// swipe-to-remove, drag-to-reorder, and a total labor footer.
// Steps are shared entities — removing a step only deletes the association,
// not the WorkStep itself.

import SwiftUI
import SwiftData

struct WorkStepListView: View {
    let product: Product

    @Query(sort: \WorkStep.title) private var allSteps: [WorkStep]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyFormatter) private var formatter

    @State private var showingNewStepForm = false
    @State private var showingExistingStepPicker = false
    @State private var linkToRemove: ProductWorkStep?
    @State private var isReordering = false
    @State private var selectedStepIDs: Set<PersistentIdentifier> = []

    // MARK: - Computed

    private var sortedLinks: [ProductWorkStep] {
        product.productWorkSteps.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var linkedStepIDs: Set<PersistentIdentifier> {
        Set(product.productWorkSteps.compactMap { $0.workStep?.persistentModelID })
    }

    private var availableSteps: [WorkStep] {
        allSteps.filter { !linkedStepIDs.contains($0.persistentModelID) }
    }

    // MARK: - Body

    var body: some View {
        GroupBox {
            if sortedLinks.isEmpty {
                emptyState
            } else {
                stepList
                totalFooter
            }
        } label: {
            groupBoxLabel
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingNewStepForm) {
            WorkStepFormView(step: nil, product: product)
        }
        .sheet(isPresented: $showingExistingStepPicker) {
            existingStepPicker
        }
        .confirmationDialog(
            "Remove step from this product?",
            isPresented: Binding(
                get: { linkToRemove != nil },
                set: { if !$0 { linkToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Step", role: .destructive) {
                if let link = linkToRemove {
                    removeLink(link)
                }
            }
            Button("Cancel", role: .cancel) {
                linkToRemove = nil
            }
        } message: {
            Text("This will remove the step from this product. The step will remain in the step library.")
        }
    }

    // MARK: - Subviews

    private var groupBoxLabel: some View {
        HStack {
            Text("Labor Workflow")
            Spacer()
            if !sortedLinks.isEmpty {
                Button {
                    withAnimation { isReordering.toggle() }
                } label: {
                    Text(isReordering ? "Done" : "Reorder")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tint)
                }
            }
            if !isReordering {
                Menu {
                    Button {
                        showingNewStepForm = true
                    } label: {
                        Label("New Step", systemImage: "plus")
                    }
                    Button {
                        showingExistingStepPicker = true
                    } label: {
                        Label("Add Existing Step", systemImage: "tray.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Text("Add work steps to calculate labor costs")
                .font(AppTheme.Typography.bodyText)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private var stepList: some View {
        VStack(spacing: 0) {
            ForEach(Array(sortedLinks.enumerated()), id: \.element.persistentModelID) { index, link in
                if let step = link.workStep {
                    if index > 0 {
                        Divider()
                            .padding(.leading, AppTheme.Spacing.md + AppTheme.Sizing.thumbnailSmall)
                    }

                    if isReordering {
                        reorderRow(step: step, link: link, index: index)
                    } else {
                        NavigationLink(value: step) {
                            stepRow(step: step)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                linkToRemove = link
                            } label: {
                                Label("Remove from Product", systemImage: "minus.circle")
                            }
                        }
                    }
                }
            }
        }
    }

    private func stepRow(step: WorkStep) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            WorkStepThumbnailView(imageData: step.image)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(step.title)
                    .font(AppTheme.Typography.rowTitle)
                    .lineLimit(1)
                Text(formatter.format(CostingEngine.stepLaborCost(step: step)))
                    .font(AppTheme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private func reorderRow(step: WorkStep, link: ProductWorkStep, index: Int) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            WorkStepThumbnailView(imageData: step.image)

            Text(step.title)
                .font(AppTheme.Typography.rowTitle)
                .lineLimit(1)

            Spacer()

            Button {
                moveStep(at: index, direction: -1)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.caption.weight(.semibold))
            }
            .disabled(index == 0)
            .buttonStyle(.bordered)

            Button {
                moveStep(at: index, direction: 1)
            } label: {
                Image(systemName: "arrow.down")
                    .font(.caption.weight(.semibold))
            }
            .disabled(index == sortedLinks.count - 1)
            .buttonStyle(.bordered)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var totalFooter: some View {
        HStack {
            Text("Total Labor")
                .font(AppTheme.Typography.sectionHeader)
            Spacer()
            Text(formatter.format(CostingEngine.totalLaborCost(product: product)))
                .font(AppTheme.Typography.sectionHeader)
                .foregroundStyle(AppTheme.Colors.accent)
        }
        .padding(.top, AppTheme.Spacing.sm)
    }

    // MARK: - Existing Step Picker

    private var existingStepPicker: some View {
        NavigationStack {
            Group {
                if availableSteps.isEmpty {
                    ContentUnavailableView(
                        "No Available Steps",
                        systemImage: "tray",
                        description: Text("All existing steps are already linked to this product. Create a new step instead.")
                    )
                } else {
                    List(availableSteps, id: \.persistentModelID) { step in
                        Button {
                            toggleSelection(step)
                        } label: {
                            HStack(spacing: AppTheme.Spacing.md) {
                                Image(systemName: selectedStepIDs.contains(step.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedStepIDs.contains(step.persistentModelID) ? AppTheme.Colors.accent : .secondary)
                                    .font(.title3)

                                WorkStepThumbnailView(imageData: step.image)

                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                    Text(step.title)
                                        .font(AppTheme.Typography.rowTitle)
                                    Text(usedByText(for: step))
                                        .font(AppTheme.Typography.rowCaption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Add Existing Steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedStepIDs.removeAll()
                        showingExistingStepPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedStepIDs.count))") {
                        addSelectedSteps()
                        selectedStepIDs.removeAll()
                        showingExistingStepPicker = false
                    }
                    .disabled(selectedStepIDs.isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func usedByText(for step: WorkStep) -> String {
        let products = step.productWorkSteps.compactMap(\.product)
        guard let first = products.first else { return "Not used" }
        let remaining = products.count - 1
        if remaining == 0 {
            return "Used by \(first.title)"
        }
        return "Used by \(first.title) + \(remaining) \(remaining == 1 ? "other" : "others")"
    }

    private func toggleSelection(_ step: WorkStep) {
        let id = step.persistentModelID
        if selectedStepIDs.contains(id) {
            selectedStepIDs.remove(id)
        } else {
            selectedStepIDs.insert(id)
        }
    }

    private func addSelectedSteps() {
        let stepsToAdd = availableSteps.filter { selectedStepIDs.contains($0.persistentModelID) }
        for step in stepsToAdd {
            addExistingStep(step)
        }
    }

    private func addExistingStep(_ step: WorkStep) {
        let link = ProductWorkStep(
            product: product,
            workStep: step,
            sortOrder: product.productWorkSteps.count
        )
        modelContext.insert(link)
        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)
    }

    private func moveStep(at index: Int, direction: Int) {
        let targetIndex = index + direction
        var links = sortedLinks
        guard targetIndex >= 0, targetIndex < links.count else { return }
        links.swapAt(index, targetIndex)
        for (i, link) in links.enumerated() {
            link.sortOrder = i
        }
    }

    private func removeLink(_ link: ProductWorkStep) {
        let linkID = link.persistentModelID
        modelContext.delete(link)
        linkToRemove = nil

        // Reindex remaining links, excluding the just-deleted one
        let remaining = product.productWorkSteps
            .filter { $0.persistentModelID != linkID }
            .sorted { $0.sortOrder < $1.sortOrder }
        for (index, remainingLink) in remaining.enumerated() {
            remainingLink.sortOrder = index
        }
    }
}
