// WorkStepDetailView.swift
// MakerMargins
//
// Scrollable detail hub for a single WorkStep.
// Shows time & batch data, cost calculations, and which products use this step.
// Pushed from ProductDetailView (Level 2) or WorkshopView (Level 1).
// Edit and delete actions in the toolbar menu.

import SwiftUI
import SwiftData

struct WorkStepDetailView: View {
    let step: WorkStep
    var product: Product?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyFormatter) private var formatter
    @Environment(\.laborRateManager) private var laborRateManager

    @State private var showingEditForm = false
    @State private var showingDeleteConfirmation = false
    @State private var showingRemoveConfirmation = false

    // Product-level editable state (initialized from join model in onAppear)
    @State private var laborRateText: String = ""
    @State private var unitsPerProductText: String = ""

    // MARK: - Computed

    /// The product to pass to WorkStepFormView for editing.
    /// Prefers the explicit product; falls back to the first linked product.
    private var editProduct: Product? {
        product ?? step.productWorkSteps.first?.product
    }

    /// The ProductWorkStep join model for this step + product combination.
    private var activeLink: ProductWorkStep? {
        guard let product else { return nil }
        return step.productWorkSteps.first { $0.product?.persistentModelID == product.persistentModelID }
    }

    private var unitTimeSeconds: TimeInterval {
        let batch = Double(truncating: step.batchUnitsCompleted as NSDecimalNumber)
        guard batch > 0 else { return 0 }
        return step.recordedTime / batch
    }

    private var editableLaborRate: Decimal {
        Decimal(string: laborRateText) ?? 0
    }

    private var editableUnitsPerProduct: Decimal {
        Decimal(string: unitsPerProductText) ?? 1
    }

    private var linkedProducts: [Product] {
        step.productWorkSteps.compactMap(\.product)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                headerSection
                stepInfoSection
                if product != nil {
                    productSettingsSection
                }
                usedBySection
                if product != nil {
                    removeFromProductSection
                }
            }
            .padding(.vertical)
        }
        .appBackground()
        .navigationTitle(step.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if let link = activeLink {
                laborRateText = "\(link.laborRate)"
                unitsPerProductText = "\(link.unitsRequiredPerProduct)"
            }
        }
        .onChange(of: laborRateText) { _, _ in
            guard let link = activeLink else { return }
            link.laborRate = editableLaborRate >= 0 ? editableLaborRate : 0
        }
        .onChange(of: unitsPerProductText) { _, _ in
            guard let link = activeLink else { return }
            link.unitsRequiredPerProduct = editableUnitsPerProduct > 0 ? editableUnitsPerProduct : 1
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        showingEditForm = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    if product == nil {
                        Menu {
                            Button("Delete Step", role: .destructive) {
                                showingDeleteConfirmation = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            WorkStepFormView(step: step, product: editProduct)
        }
        .confirmationDialog(
            "Delete \"\(step.title)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Step", role: .destructive) {
                modelContext.delete(step)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this step and remove it from all products that use it. This action cannot be undone.")
        }
        .confirmationDialog(
            "Remove from \"\(product?.title ?? "")\"?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Step", role: .destructive) {
                removeFromProduct()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the step from this product only. It will remain available in the step library.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if let data = step.image, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: AppTheme.Sizing.detailImageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
                    .padding(.horizontal)
            } else {
                PlaceholderImageView(
                    height: AppTheme.Sizing.detailPlaceholderHeight,
                    cornerRadius: AppTheme.CornerRadius.large,
                    iconFont: .largeTitle
                )
                .padding(.horizontal)
            }

            if !step.summary.isEmpty {
                Text(step.summary)
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    private var stepInfoSection: some View {
        GroupBox("Step Info") {
            VStack(spacing: 0) {
                DetailRow(label: "Time to Complete Batch", value: CostingEngine.formatDuration(step.recordedTime))
                Divider()
                DetailRow(label: "\(step.unitName.capitalized)s per Batch", value: "\(step.batchUnitsCompleted) \(step.unitName)\(step.batchUnitsCompleted == 1 ? "" : "s")")
                Divider()
                DerivedRow(label: "Time per \(step.unitName)", value: CostingEngine.formatDuration(unitTimeSeconds))
                Divider()
                HStack {
                    Text("Hours per \(step.unitName)")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    Text(CostingEngine.formatHours(CostingEngine.unitTimeHours(step: step)))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                }
                .padding(.vertical, AppTheme.Spacing.sm)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var productSettingsSection: some View {
        GroupBox("Product Settings") {
            VStack(spacing: 0) {
                // Editable: Labor Rate
                HStack {
                    Text("Labor Rate")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    CurrencyInputField(
                        symbol: formatter.symbol,
                        text: $laborRateText,
                        suffix: "/hr"
                    )
                    .editableFieldStyle()
                }
                .padding(.vertical, AppTheme.Spacing.sm)

                Divider()

                // Editable: Units per Product
                HStack {
                    Text("\(step.unitName.capitalized)s per Product")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    TextField("1", text: $unitsPerProductText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: AppTheme.Sizing.inputMedium)
                        .editableFieldStyle()
                }
                .padding(.vertical, AppTheme.Spacing.sm)

                Divider()

                // Calculated: Labor Hours per Product
                let laborHours = CostingEngine.laborHoursPerProduct(
                    recordedTime: step.recordedTime,
                    batchUnitsCompleted: step.batchUnitsCompleted,
                    unitsRequiredPerProduct: editableUnitsPerProduct
                )
                DerivedRow(label: "Labor Hrs / Product", value: CostingEngine.formatHours(laborHours))

                Divider()

                // Calculated: Labor Cost per Product
                let laborCost = CostingEngine.stepLaborCost(
                    recordedTime: step.recordedTime,
                    batchUnitsCompleted: step.batchUnitsCompleted,
                    unitsRequiredPerProduct: editableUnitsPerProduct,
                    laborRate: editableLaborRate
                )
                HStack {
                    Text("Labor Cost / Product")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    Text(formatter.format(laborCost))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                }
                .padding(.vertical, AppTheme.Spacing.sm)
            }
        }
        .padding(.horizontal)
    }

    private var usedBySection: some View {
        GroupBox("Used By") {
            if linkedProducts.isEmpty {
                HStack {
                    Text("This step is not linked to any products")
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, AppTheme.Spacing.xs)
            } else {
                VStack(spacing: 0) {
                    ForEach(linkedProducts, id: \.persistentModelID) { linkedProduct in
                        HStack(spacing: AppTheme.Spacing.md) {
                            ProductThumbnailView(imageData: linkedProduct.image)
                            Text(linkedProduct.title)
                                .font(AppTheme.Typography.rowTitle)
                            Spacer()
                        }
                        .padding(.vertical, AppTheme.Spacing.sm)

                        if linkedProduct.persistentModelID != linkedProducts.last?.persistentModelID {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var removeFromProductSection: some View {
        if let product {
            Button(role: .destructive) {
                showingRemoveConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("Remove from \(product.title)", systemImage: "minus.circle")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                }
                .padding(.vertical, AppTheme.Spacing.md)
                .background(
                    Color.red.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 0.5)
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func removeFromProduct() {
        guard let link = activeLink, let product else { return }
        let linkID = link.persistentModelID
        modelContext.delete(link)

        // Reindex remaining links
        let remaining = product.productWorkSteps
            .filter { $0.persistentModelID != linkID }
            .sorted { $0.sortOrder < $1.sortOrder }
        for (index, remainingLink) in remaining.enumerated() {
            remainingLink.sortOrder = index
        }
        dismiss()
    }

}
