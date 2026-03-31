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
    var onNewStepCreated: ((WorkStep) -> Void)? = nil

    @Query(sort: \WorkStep.title) private var allSteps: [WorkStep]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyFormatter) private var formatter
    @Environment(\.laborRateManager) private var laborRateManager

    @State private var showingNewStepForm = false
    @State private var showingExistingStepPicker = false
    @State private var linkToRemove: ProductWorkStep?
    @State private var isReordering = false
    @State private var selectedStepIDs: [PersistentIdentifier] = []
    @State private var bufferText: String
    @State private var stepCountBeforeSheet = 0
    @FocusState private var bufferFocused: Bool

    // MARK: - Init

    init(product: Product, onNewStepCreated: ((WorkStep) -> Void)? = nil) {
        self.product = product
        self.onNewStepCreated = onNewStepCreated
        _bufferText = State(initialValue: "\(product.laborBuffer * 100)")
    }

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

    private var bufferFraction: Decimal {
        (Decimal(string: bufferText) ?? 0) / 100
    }

    // MARK: - Body

    var body: some View {
        GroupBox {
            if sortedLinks.isEmpty {
                emptyState
            } else {
                stepList
            }
            bufferSection
        } label: {
            groupBoxLabel
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingNewStepForm, onDismiss: {
            if product.productWorkSteps.count > stepCountBeforeSheet,
               let newestLink = product.productWorkSteps
                   .sorted(by: { $0.sortOrder < $1.sortOrder }).last,
               let newStep = newestLink.workStep {
                onNewStepCreated?(newStep)
            }
        }) {
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
            Text("This will remove the step from this product only. It will remain available in the step library.")
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
                        stepCountBeforeSheet = product.productWorkSteps.count
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
                        reorderRow(link: link, index: index)
                    } else {
                        NavigationLink(value: step) {
                            stepRow(link: link)
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

    private func stepRow(link: ProductWorkStep) -> some View {
        let step = link.workStep!
        return HStack(spacing: AppTheme.Spacing.md) {
            WorkStepThumbnailView(imageData: step.image)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(step.title)
                    .font(AppTheme.Typography.rowTitle)
                    .lineLimit(1)
                Text(formatter.format(CostingEngine.stepLaborCost(link: link)))
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

    private func reorderRow(link: ProductWorkStep, index: Int) -> some View {
        let step = link.workStep!
        return HStack(spacing: AppTheme.Spacing.md) {
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

    private var bufferSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Divider()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text("Labor Cost Buffer")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        TextField("0", text: $bufferText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: AppTheme.Sizing.inputBuffer)
                            .focused($bufferFocused)
                        Text("%")
                            .font(AppTheme.Typography.bodyText)
                            .foregroundStyle(.secondary)
                    }
                    .editableFieldStyle()
                }
                Text("Adds a percentage on top of the base labor cost")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
            .onChange(of: bufferText) { _, _ in
                product.laborBuffer = bufferFraction
            }
            .onChange(of: bufferFocused) { _, focused in
                if focused {
                    if bufferText == "0" { bufferText = "" }
                } else {
                    if bufferText.trimmingCharacters(in: .whitespaces).isEmpty { bufferText = "0" }
                }
            }

            HStack {
                Text("Total Labor")
                    .font(AppTheme.Typography.sectionHeader)
                Spacer()
                Text(formatter.format(CostingEngine.totalLaborCostBuffered(product: product)))
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }
        .padding(.top, AppTheme.Spacing.xs)
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
                                    Text(UsageText.from(products: step.productWorkSteps.compactMap(\.product)))
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

    private func toggleSelection(_ step: WorkStep) {
        let id = step.persistentModelID
        if let index = selectedStepIDs.firstIndex(of: id) {
            selectedStepIDs.remove(at: index)
        } else {
            selectedStepIDs.append(id)
        }
    }

    private func addSelectedSteps() {
        for id in selectedStepIDs {
            if let step = availableSteps.first(where: { $0.persistentModelID == id }) {
                addExistingStep(step)
            }
        }
    }

    private func addExistingStep(_ step: WorkStep) {
        let link = ProductWorkStep(
            product: product,
            workStep: step,
            sortOrder: product.productWorkSteps.count,
            unitsRequiredPerProduct: step.defaultUnitsPerProduct,
            laborRate: laborRateManager.defaultRate
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
