// MaterialsLibraryView.swift
// MakerMargins
//
// Tab 3 root — the shared material library.
// Displays all Materials across all products, searchable by title.
// Each row shows material title, product usage count, and cost per unit.
// Tapping a row pushes MaterialDetailView for viewing and editing.
// Materials can also be created here as standalone library entries (no product link).

import SwiftUI
import SwiftData

struct MaterialsLibraryView: View {
    @Query(sort: \Material.title) private var allMaterials: [Material]
    @Environment(\.currencyFormatter) private var formatter

    @State private var searchText = ""
    @State private var showingCreateForm = false

    // MARK: - Computed

    private var filteredMaterials: [Material] {
        if searchText.isEmpty {
            return allMaterials
        }
        return allMaterials.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if allMaterials.isEmpty {
                ContentUnavailableView(
                    "No Materials",
                    systemImage: "shippingbox",
                    description: Text("Tap + to create a material, or add materials from a product's detail view.")
                )
            } else if filteredMaterials.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                materialList
            }
        }
        .navigationTitle("Materials")
        .searchable(text: $searchText, prompt: "Search materials")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: Material.self) { material in
            MaterialDetailView(material: material)
        }
        .sheet(isPresented: $showingCreateForm) {
            MaterialFormView(material: nil, product: nil)
        }
    }

    // MARK: - Helpers

    // MARK: - Material List

    private var materialList: some View {
        List(filteredMaterials, id: \.persistentModelID) { material in
            NavigationLink(value: material) {
                HStack(spacing: AppTheme.Spacing.md) {
                    MaterialThumbnailView(imageData: material.image)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(material.title)
                            .font(AppTheme.Typography.rowTitle)
                            .lineLimit(1)

                        HStack(spacing: AppTheme.Spacing.sm) {
                            Text(UsageText.from(products: material.productMaterials.compactMap(\.product)))
                                .font(AppTheme.Typography.rowCaption)
                                .foregroundStyle(.secondary)

                            Text("·")
                                .foregroundStyle(.tertiary)

                            Text("\(formatter.format(CostingEngine.materialUnitCost(material: material)))/\(material.unitName)")
                                .font(AppTheme.Typography.rowCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
    }
}
