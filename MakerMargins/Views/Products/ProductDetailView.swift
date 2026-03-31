// ProductDetailView.swift
// MakerMargins
//
// Scrollable hub for a single Product.
// Epic 1: header, cost summary card, materials placeholder.
// Epic 2: live labor section via WorkStepListView, navigation to WorkStepDetailView.

import SwiftUI
import SwiftData

/// Wrapper types to avoid conflicting with existing navigationDestination(for:) registrations.
private struct NewWorkStepNav: Hashable {
    let step: WorkStep
    static func == (lhs: NewWorkStepNav, rhs: NewWorkStepNav) -> Bool {
        lhs.step.persistentModelID == rhs.step.persistentModelID
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(step.persistentModelID)
    }
}

private struct NewMaterialNav: Hashable {
    let material: Material
    static func == (lhs: NewMaterialNav, rhs: NewMaterialNav) -> Bool {
        lhs.material.persistentModelID == rhs.material.persistentModelID
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(material.persistentModelID)
    }
}

struct ProductDetailView: View {
    let product: Product

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Environment(\.currencyFormatter) private var formatter

    @State private var showingEditForm = false
    @State private var showingDeleteConfirmation = false
    @State private var pendingWorkStep: NewWorkStepNav?
    @State private var pendingMaterial: NewMaterialNav?
    @State private var shippingCostText: String = ""
    @FocusState private var shippingFocused: Bool
    @State private var laborExpanded = true
    @State private var materialsExpanded = true
    @State private var shippingExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                headerSection
                ProductCostSummaryCard(product: product)
                    .padding(.horizontal)
                laborSection
                materialsSection
                shippingSection
                PricingCalculatorView(product: product)
            }
            .padding(.vertical)
        }
        .appBackground()
        .onAppear {
            shippingCostText = "\(product.shippingCost)"
        }
        .navigationDestination(for: WorkStep.self) { step in
            WorkStepDetailView(step: step, product: product)
        }
        .navigationDestination(for: Material.self) { material in
            MaterialDetailView(material: material, product: product)
        }
        .navigationDestination(item: $pendingWorkStep) { nav in
            WorkStepDetailView(step: nav.step, product: product)
        }
        .navigationDestination(item: $pendingMaterial) { nav in
            MaterialDetailView(material: nav.material, product: product)
        }
        .navigationTitle(product.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit Product") {
                        showingEditForm = true
                    }
                    Divider()
                    Button("Delete Product", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            ProductFormView(product: product)
        }
        .confirmationDialog(
            "Delete \"\(product.title)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Product", role: .destructive) {
                modelContext.delete(product)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this product. Work steps and materials will remain in their libraries. This action cannot be undone.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if let data = product.image, let uiImage = UIImage(data: data) {
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

            VStack(alignment: .leading, spacing: AppTheme.Spacing.smd) {
                if let category = product.category {
                    Text(category.name)
                        .font(AppTheme.Typography.badge)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(AppTheme.Colors.categoryBadgeBackground, in: Capsule())
                        .foregroundStyle(AppTheme.Colors.categoryBadge)
                }
                if !product.sku.isEmpty {
                    Text("SKU: \(product.sku)")
                        .font(AppTheme.Typography.rowCaption)
                        .foregroundStyle(.secondary)
                }
                if !product.summary.isEmpty {
                    Text(product.summary)
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }

    private var laborSection: some View {
        WorkStepListView(product: product, isExpanded: $laborExpanded) { newStep in
            pendingWorkStep = NewWorkStepNav(step: newStep)
        }
    }

    private var materialsSection: some View {
        MaterialListView(product: product, isExpanded: $materialsExpanded) { newMaterial in
            pendingMaterial = NewMaterialNav(material: newMaterial)
        }
    }

    private var shippingSection: some View {
        GroupBox {
            DisclosureGroup("Shipping", isExpanded: $shippingExpanded) {
                HStack {
                    Text("Average Shipping Cost")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    CurrencyInputField(
                        symbol: formatter.symbol,
                        text: $shippingCostText
                    )
                    .editableFieldStyle()
                    .focused($shippingFocused)
                }
                .padding(.vertical, AppTheme.Spacing.sm)
            }
        }
        .padding(.horizontal)
        .onChange(of: shippingCostText) { _, _ in
            let value = Decimal(string: shippingCostText) ?? 0
            product.shippingCost = value >= 0 ? value : 0
        }
        .onChange(of: shippingFocused) { _, focused in
            if focused {
                if shippingCostText == "0" { shippingCostText = "" }
            } else {
                if shippingCostText.trimmingCharacters(in: .whitespaces).isEmpty { shippingCostText = "0" }
            }
        }
    }
}
