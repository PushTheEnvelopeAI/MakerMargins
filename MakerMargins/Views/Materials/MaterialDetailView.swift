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

    // MARK: - Computed

    private var editProduct: Product? {
        product ?? material.productMaterials.first?.product
    }

    private var linkedProducts: [Product] {
        material.productMaterials.compactMap(\.product)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                headerSection
                purchaseSection
                costSection
                usedBySection
            }
            .padding(.vertical)
        }
        .appBackground()
        .navigationTitle(material.title)
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
                        Button("Delete Material", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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

    private var purchaseSection: some View {
        GroupBox("Purchase") {
            VStack(spacing: 0) {
                DetailRow(label: "Bulk Cost", value: formatter.format(material.bulkCost))
                Divider()
                DetailRow(label: "\(material.unitName.capitalized)s in Purchase", value: "\(material.bulkQuantity)")
                Divider()
                DetailRow(label: "Unit Name", value: material.unitName)
                Divider()
                DetailRow(label: "\(material.unitName.capitalized)s per Product", value: "\(material.unitsRequiredPerProduct)")
            }
        }
        .padding(.horizontal)
    }

    private var costSection: some View {
        GroupBox("Cost") {
            VStack(spacing: 0) {
                DerivedRow(label: "Cost per \(material.unitName)", value: formatter.format(CostingEngine.materialUnitCost(material: material)))
                Divider()
                HStack {
                    Text("Material Cost per Product")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    Text(formatter.format(CostingEngine.materialLineCost(material: material)))
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

}
