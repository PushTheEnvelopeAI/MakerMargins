// ProductDetailView.swift
// MakerMargins
//
// Product workspace with pinned header and segmented sub-tabs.
// Build tab: cost summary, labor workflow, materials, shipping.
// Price tab: target price calculator + profit analysis.
// Forecast tab: batch forecasting (Epic 5 stub).

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

    // MARK: - Sub-tabs

    private enum DetailTab: String, CaseIterable {
        case build = "Build"
        case price = "Price"
        case forecast = "Forecast"
    }

    @State private var selectedTab: DetailTab = .build

    // MARK: - State

    @State private var showingEditForm = false
    @State private var showingDeleteConfirmation = false
    @State private var pendingWorkStep: NewWorkStepNav?
    @State private var pendingMaterial: NewMaterialNav?
    @State private var shippingCostText: String = ""
    @FocusState private var shippingFocused: Bool
    @State private var laborExpanded = true
    @State private var materialsExpanded = true
    @State private var shippingExpanded = true
    @State private var hasAutoSwitchedTab = false

    var body: some View {
        VStack(spacing: 0) {
            pinnedHeader
            tabContent
        }
        .appBackground()
        .onAppear {
            shippingCostText = "\(product.shippingCost)"
            if !hasAutoSwitchedTab,
               product.productPricings.contains(where: { $0.actualPrice > 0 }) {
                selectedTab = .price
                hasAutoSwitchedTab = true
            }
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
        .onChange(of: pendingWorkStep) { _, new in
            if new != nil { selectedTab = .build }
        }
        .onChange(of: pendingMaterial) { _, new in
            if new != nil { selectedTab = .build }
        }
        .navigationTitle(product.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        showingEditForm = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit \(product.title)")
                    Menu {
                        Button("Duplicate Product") {
                            duplicateCurrentProduct()
                        }
                        Divider()
                        Button("Delete Product", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More options")
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

    // MARK: - Pinned Header

    private var pinnedHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            compactHeaderSection

            Picker("Section", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .padding(.bottom, AppTheme.Spacing.sm)
    }

    /// Compact product context for the pinned header — category badge, SKU, description.
    private var compactHeaderSection: some View {
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
                    .lineLimit(2)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .build:
            buildTabContent
        case .price:
            priceTabContent
        case .forecast:
            forecastTabContent
        }
    }

    private var buildTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                headerImageSection
                ProductCostSummaryCard(product: product)
                    .padding(.horizontal)
                laborSection
                materialsSection
                shippingSection
            }
            .padding(.vertical)
        }
    }

    private var priceTabContent: some View {
        ScrollView {
            PricingCalculatorView(product: product)
                .padding(.vertical)
        }
    }

    private var forecastTabContent: some View {
        ScrollView {
            BatchForecastView(product: product)
                .padding(.vertical)
        }
    }

    // MARK: - Sections

    /// Full product image — shown at the top of the Build tab.
    @ViewBuilder
    private var headerImageSection: some View {
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

    private func duplicateCurrentProduct() {
        let copy = Product(
            title: "\(product.title) (Copy)",
            sku: product.sku,
            summary: product.summary,
            image: product.image,
            shippingCost: product.shippingCost,
            materialBuffer: product.materialBuffer,
            laborBuffer: product.laborBuffer,
            category: product.category
        )
        modelContext.insert(copy)

        for link in product.productWorkSteps {
            guard let step = link.workStep else { continue }
            let newLink = ProductWorkStep(
                product: copy, workStep: step,
                sortOrder: link.sortOrder,
                unitsRequiredPerProduct: link.unitsRequiredPerProduct,
                laborRate: link.laborRate
            )
            modelContext.insert(newLink)
        }

        for link in product.productMaterials {
            guard let mat = link.material else { continue }
            let newLink = ProductMaterial(
                product: copy, material: mat,
                sortOrder: link.sortOrder,
                unitsRequiredPerProduct: link.unitsRequiredPerProduct
            )
            modelContext.insert(newLink)
        }

        for pricing in product.productPricings {
            let newPricing = ProductPricing(
                product: copy,
                platformType: pricing.platformType,
                platformFee: pricing.platformFee,
                paymentProcessingFee: pricing.paymentProcessingFee,
                marketingFee: pricing.marketingFee,
                percentSalesFromMarketing: pricing.percentSalesFromMarketing,
                profitMargin: pricing.profitMargin,
                actualPrice: pricing.actualPrice,
                actualShippingCharge: pricing.actualShippingCharge
            )
            modelContext.insert(newPricing)
        }
    }
}
