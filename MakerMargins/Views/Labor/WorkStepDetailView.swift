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

    @State private var showingEditForm = false
    @State private var showingDeleteConfirmation = false

    // MARK: - Computed

    /// The product to pass to WorkStepFormView for editing.
    /// Prefers the explicit product; falls back to the first linked product.
    private var editProduct: Product? {
        product ?? step.productWorkSteps.first?.product
    }

    private var unitTimeSeconds: TimeInterval {
        let batch = Double(truncating: step.batchUnitsCompleted as NSDecimalNumber)
        guard batch > 0 else { return 0 }
        return step.recordedTime / batch
    }

    private var activeUnitsPerProduct: Decimal {
        if let product {
            let link = step.productWorkSteps.first { $0.product?.persistentModelID == product.persistentModelID }
            return link?.unitsRequiredPerProduct ?? step.defaultUnitsPerProduct
        }
        return step.defaultUnitsPerProduct
    }

    private var timePerProduct: TimeInterval {
        unitTimeSeconds * Double(truncating: activeUnitsPerProduct as NSDecimalNumber)
    }

    private var linkedProducts: [Product] {
        step.productWorkSteps.compactMap(\.product)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                headerSection
                timeBatchSection
                costSection
                usedBySection
            }
            .padding(.vertical)
        }
        .appBackground()
        .navigationTitle(step.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        showingEditForm = true
                    } label: {
                        Image(systemName: "pencil")
                    }
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

    private var timeBatchSection: some View {
        GroupBox("Time & Batch") {
            VStack(spacing: 0) {
                DetailRow(label: "Recorded Time", value: CostingEngine.formatDuration(step.recordedTime))
                Divider()
                DetailRow(label: "\(step.unitName.capitalized)s Completed", value: "\(step.batchUnitsCompleted) \(step.unitName)\(step.batchUnitsCompleted == 1 ? "" : "s")")
                Divider()
                DerivedRow(label: "Time per \(step.unitName)", value: CostingEngine.formatDuration(unitTimeSeconds))
                Divider()
                DetailRow(label: "\(step.unitName.capitalized)s per Product", value: "\(activeUnitsPerProduct)")
                Divider()
                DerivedRow(label: "Time per Product", value: CostingEngine.formatDuration(timePerProduct))
            }
        }
        .padding(.horizontal)
    }

    private var costSection: some View {
        GroupBox("Cost") {
            VStack(spacing: 0) {
                DetailRow(label: "Hourly Rate", value: "\(formatter.format(step.laborRate))/hr")
                Divider()
                HStack {
                    Text("Labor Cost per Product")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    Text(formatter.format(CostingEngine.stepLaborCost(step: step)))
                        .font(AppTheme.Typography.sectionHeader)
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

}
