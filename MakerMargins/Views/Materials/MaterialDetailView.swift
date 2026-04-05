// MaterialDetailView.swift
// MakerMargins
//
// Scrollable detail hub for a single Material.
// Shows purchase data, cost calculations, and which products use this material.
// Pushed from ProductDetailView (Level 2) or MaterialsLibraryView (Level 1).
// Edit and delete actions in the toolbar menu.

import SwiftUI
import SwiftData

struct MaterialDetailView: View {
    let material: Material
    var product: Product?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyFormatter) private var formatter

    @State private var showingEditForm = false
    @State private var showingDeleteConfirmation = false
    @State private var showingRemoveConfirmation = false

    // Product-level editable state (initialized from join model in onAppear)
    @State private var unitsPerProductText: String = ""

    // MARK: - Computed

    private var editProduct: Product? {
        product ?? material.productMaterials.first?.product
    }

    /// The ProductMaterial join model for this material + product combination.
    private var activeLink: ProductMaterial? {
        guard let product else { return nil }
        return material.productMaterials.first { $0.product?.persistentModelID == product.persistentModelID }
    }

    private var editableUnitsPerProduct: Decimal {
        Decimal(string: unitsPerProductText) ?? 1
    }

    private var linkedProducts: [Product] {
        material.productMaterials.compactMap(\.product)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                headerSection
                materialInfoSection
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
        .navigationTitle(material.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if let link = activeLink {
                unitsPerProductText = "\(link.unitsRequiredPerProduct)"
            }
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
                    .accessibilityLabel("Edit \(material.title)")
                    if product == nil {
                        Menu {
                            Button("Delete Material", role: .destructive) {
                                showingDeleteConfirmation = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("More options")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            MaterialFormView(material: material, product: editProduct)
        }
        .confirmationDialog(
            "Delete \"\(material.title)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Material", role: .destructive) {
                modelContext.delete(material)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this material and remove it from all products that use it. This action cannot be undone.")
        }
        .confirmationDialog(
            "Remove from \"\(product?.title ?? "")\"?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Material", role: .destructive) {
                removeFromProduct()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the material from this product only. It will remain available in the material library.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if let data = material.image, let uiImage = UIImage(data: data) {
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

            if !material.summary.isEmpty {
                Text(material.summary)
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            if !material.link.isEmpty {
                Group {
                    if let url = URL(string: material.link) {
                        Link(destination: url) {
                            Label(material.link, systemImage: "link")
                                .font(AppTheme.Typography.bodyText)
                                .lineLimit(1)
                        }
                    } else {
                        Label(material.link, systemImage: "link")
                            .font(AppTheme.Typography.bodyText)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var materialInfoSection: some View {
        GroupBox("Material Info") {
            VStack(spacing: 0) {
                DetailRow(label: "Bulk Cost", value: formatter.format(material.bulkCost))
                Divider()
                DetailRow(label: "\(material.unitName.capitalized)s in Purchase", value: "\(material.bulkQuantity)")
                Divider()
                DetailRow(label: "Unit Name", value: material.unitName)
                Divider()
                HStack {
                    Text("Cost per \(material.unitName)")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    Text(formatter.format(CostingEngine.materialUnitCost(material: material)))
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
                // Editable: Units per Product
                HStack {
                    Text("\(material.unitName.capitalized)s per Product")
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

                // Calculated: Material Cost per Product
                let materialCost = CostingEngine.materialLineCost(
                    bulkCost: material.bulkCost,
                    bulkQuantity: material.bulkQuantity,
                    unitsRequiredPerProduct: editableUnitsPerProduct
                )
                HStack {
                    Text("Material Cost / Product")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    Text(formatter.format(materialCost))
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
                    Text("This material is not linked to any products")
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
        let remaining = product.productMaterials
            .filter { $0.persistentModelID != linkID }
            .sorted { $0.sortOrder < $1.sortOrder }
        for (index, remainingLink) in remaining.enumerated() {
            remainingLink.sortOrder = index
        }
        dismiss()
    }

}
