// MaterialsLibraryView.swift
// MakerMargins
//
// Tab 3 root — the shared material library.
// Displays all Materials across all products, searchable by title.
// Each row shows material title, product usage count, and cost per unit.
// Tapping a row pushes MaterialDetailView for viewing and editing.
// Materials can also be created here as standalone library entries (no product link).
// Supports multi-select deletion via Edit mode.

import SwiftUI
import SwiftData

struct MaterialsLibraryView: View {
    @Query(sort: \Material.title) private var allMaterials: [Material]
    @Environment(\.currencyFormatter) private var formatter
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var showingCreateForm = false
    @State private var navigationPath = NavigationPath()
    @State private var materialCountBeforeSheet = 0
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<Material.ID>()
    @State private var showingDeleteConfirmation = false

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
        NavigationStack(path: $navigationPath) {
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
                        materialCountBeforeSheet = allMaterials.count
                        showingCreateForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create material")
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !allMaterials.isEmpty {
                        EditButton()
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .onChange(of: editMode) { _, newValue in
                if !newValue.isEditing { selection.removeAll() }
            }
            .navigationDestination(for: Material.self) { material in
                MaterialDetailView(material: material)
            }
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
            .sheet(isPresented: $showingCreateForm, onDismiss: {
                if allMaterials.count > materialCountBeforeSheet,
                   let newMaterial = allMaterials.last {
                    navigationPath.append(newMaterial)
                }
            }) {
                MaterialFormView(material: nil, product: nil)
            }
            .confirmationDialog(
                "Delete \(selection.count) Material\(selection.count == 1 ? "" : "s")?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(selection.count) Material\(selection.count == 1 ? "" : "s")", role: .destructive) {
                    deleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the selected material\(selection.count == 1 ? "" : "s") and remove \(selection.count == 1 ? "it" : "them") from all products. This action cannot be undone.")
            }
        }
    }

    // MARK: - Material List

    private var materialList: some View {
        List(filteredMaterials, id: \.persistentModelID, selection: $selection) { material in
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
        .safeAreaInset(edge: .bottom) {
            if editMode.isEditing && !selection.isEmpty {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Text("Delete \(selection.count) Material\(selection.count == 1 ? "" : "s")")
                        .font(AppTheme.Typography.sectionHeader)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(AppTheme.Colors.destructive.opacity(0.1), in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.sm)
            }
        }
    }

    // MARK: - Actions

    private func deleteSelected() {
        let materialsToDelete = allMaterials.filter { selection.contains($0.persistentModelID) }
        for material in materialsToDelete {
            modelContext.delete(material)
        }
        selection.removeAll()
        editMode = .inactive
    }
}
