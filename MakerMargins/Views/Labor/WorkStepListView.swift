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
            Text("Labor")
            Spacer()
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
        List {
            ForEach(sortedLinks, id: \.persistentModelID) { link in
                if let step = link.workStep {
                    NavigationLink(value: step) {
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
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            linkToRemove = link
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                    }
                }
            }
            .onMove(perform: moveSteps)
        }
        .listStyle(.plain)
        .frame(minHeight: CGFloat(sortedLinks.count) * 60)
        .scrollDisabled(true)
        .environment(\.editMode, .constant(.active))
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
                            addExistingStep(step)
                            showingExistingStepPicker = false
                        } label: {
                            HStack(spacing: AppTheme.Spacing.md) {
                                WorkStepThumbnailView(imageData: step.image)

                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                    Text(step.title)
                                        .font(AppTheme.Typography.rowTitle)
                                    let usageCount = step.productWorkSteps.count
                                    Text("Used by \(usageCount) \(usageCount == 1 ? "product" : "products")")
                                        .font(AppTheme.Typography.rowCaption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Add Existing Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingExistingStepPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

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

    private func moveSteps(from source: IndexSet, to destination: Int) {
        var links = sortedLinks
        links.move(fromOffsets: source, toOffset: destination)
        for (index, link) in links.enumerated() {
            link.sortOrder = index
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
