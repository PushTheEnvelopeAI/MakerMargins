// MaterialListView.swift
// MakerMargins
//
// Inline component embedded in ProductDetailView.
// Displays a product's materials sorted by sortOrder, with add (new or existing),
// swipe-to-remove, reorder, a total material footer, and inline buffer editing.
// Materials are shared entities — removing a material only deletes the association,
// not the Material itself.

import SwiftUI
import SwiftData

struct MaterialListView: View {
    let product: Product
    var onNewMaterialCreated: ((Material) -> Void)? = nil
    @Binding var isExpanded: Bool

    @Query(sort: \Material.title) private var allMaterials: [Material]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyFormatter) private var formatter

    @State private var showingNewMaterialForm = false
    @State private var showingExistingMaterialPicker = false
    @State private var linkToRemove: ProductMaterial?
    @State private var isReordering = false
    @State private var selectedMaterialIDs: [PersistentIdentifier] = []
    @State private var bufferText: String
    @State private var materialCountBeforeSheet = 0
    @FocusState private var bufferFocused: Bool

    // MARK: - Init

    init(product: Product, isExpanded: Binding<Bool>, onNewMaterialCreated: ((Material) -> Void)? = nil) {
        self.product = product
        self._isExpanded = isExpanded
        self.onNewMaterialCreated = onNewMaterialCreated
        _bufferText = State(initialValue: "\(product.materialBuffer * 100)")
    }

    // MARK: - Computed

    private var sortedLinks: [ProductMaterial] {
        product.productMaterials.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var linkedMaterialIDs: Set<PersistentIdentifier> {
        Set(product.productMaterials.compactMap { $0.material?.persistentModelID })
    }

    private var availableMaterials: [Material] {
        allMaterials.filter { !linkedMaterialIDs.contains($0.persistentModelID) }
    }

    private var bufferFraction: Decimal {
        (Decimal(string: bufferText) ?? 0) / 100
    }

    // MARK: - Body

    var body: some View {
        GroupBox {
            DisclosureGroup(isExpanded: $isExpanded) {
                if sortedLinks.isEmpty {
                    emptyState
                } else {
                    materialList
                }
                bufferSection
            } label: {
                groupBoxLabel
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingNewMaterialForm, onDismiss: {
            if product.productMaterials.count > materialCountBeforeSheet,
               let newestLink = product.productMaterials
                   .sorted(by: { $0.sortOrder < $1.sortOrder }).last,
               let newMaterial = newestLink.material {
                onNewMaterialCreated?(newMaterial)
            }
        }) {
            MaterialFormView(material: nil, product: product)
        }
        .sheet(isPresented: $showingExistingMaterialPicker) {
            existingMaterialPicker
        }
        .confirmationDialog(
            "Remove material from this product?",
            isPresented: Binding(
                get: { linkToRemove != nil },
                set: { if !$0 { linkToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Material", role: .destructive) {
                if let link = linkToRemove {
                    removeLink(link)
                }
            }
            Button("Cancel", role: .cancel) {
                linkToRemove = nil
            }
        } message: {
            Text("This will remove the material from this product only. It will remain available in the material library.")
        }
    }

    // MARK: - Subviews

    private var groupBoxLabel: some View {
        HStack {
            Text("Materials")
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
                        materialCountBeforeSheet = product.productMaterials.count
                        showingNewMaterialForm = true
                    } label: {
                        Label("New Material", systemImage: "plus")
                    }
                    Button {
                        showingExistingMaterialPicker = true
                    } label: {
                        Label("Add Existing Material", systemImage: "tray.and.arrow.down")
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
            Text("Add materials to calculate material costs")
                .font(AppTheme.Typography.bodyText)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private var materialList: some View {
        VStack(spacing: 0) {
            ForEach(Array(sortedLinks.enumerated()), id: \.element.persistentModelID) { index, link in
                if let material = link.material {
                    if index > 0 {
                        Divider()
                            .padding(.leading, AppTheme.Spacing.md + AppTheme.Sizing.thumbnailSmall)
                    }

                    if isReordering {
                        reorderRow(link: link, index: index)
                    } else {
                        NavigationLink(value: material) {
                            materialRow(link: link)
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

    private func materialRow(link: ProductMaterial) -> some View {
        let material = link.material!
        return HStack(spacing: AppTheme.Spacing.md) {
            MaterialThumbnailView(imageData: material.image)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(material.title)
                    .font(AppTheme.Typography.rowTitle)
                    .lineLimit(1)
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(formatter.format(CostingEngine.materialLineCost(link: link)))
                        .font(AppTheme.Typography.rowCaption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(link.unitsRequiredPerProduct) \(material.unitName)/product")
                        .font(AppTheme.Typography.rowCaption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private func reorderRow(link: ProductMaterial, index: Int) -> some View {
        let material = link.material!
        return HStack(spacing: AppTheme.Spacing.md) {
            MaterialThumbnailView(imageData: material.image)

            Text(material.title)
                .font(AppTheme.Typography.rowTitle)
                .lineLimit(1)

            Spacer()

            Button {
                moveMaterial(at: index, direction: -1)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.caption.weight(.semibold))
            }
            .disabled(index == 0)
            .buttonStyle(.bordered)

            Button {
                moveMaterial(at: index, direction: 1)
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
                    Text("Material Cost Buffer")
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
                Text("Adds a percentage on top of the base material cost")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
            .onChange(of: bufferText) { _, _ in
                product.materialBuffer = bufferFraction
            }
            .onChange(of: bufferFocused) { _, focused in
                if focused {
                    if bufferText == "0" { bufferText = "" }
                } else {
                    if bufferText.trimmingCharacters(in: .whitespaces).isEmpty { bufferText = "0" }
                }
            }

            HStack {
                Text("Total Materials")
                    .font(AppTheme.Typography.sectionHeader)
                Spacer()
                Text(formatter.format(CostingEngine.totalMaterialCostBuffered(product: product)))
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }
        .padding(.top, AppTheme.Spacing.xs)
    }

    // MARK: - Existing Material Picker

    private var existingMaterialPicker: some View {
        NavigationStack {
            Group {
                if availableMaterials.isEmpty {
                    ContentUnavailableView(
                        "No Available Materials",
                        systemImage: "tray",
                        description: Text("All existing materials are already linked to this product. Create a new material instead.")
                    )
                } else {
                    List(availableMaterials, id: \.persistentModelID) { material in
                        Button {
                            toggleSelection(material)
                        } label: {
                            HStack(spacing: AppTheme.Spacing.md) {
                                Image(systemName: selectedMaterialIDs.contains(material.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedMaterialIDs.contains(material.persistentModelID) ? AppTheme.Colors.accent : .secondary)
                                    .font(.title3)

                                MaterialThumbnailView(imageData: material.image)

                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                    Text(material.title)
                                        .font(AppTheme.Typography.rowTitle)
                                    Text(UsageText.from(products: material.productMaterials.compactMap(\.product)))
                                        .font(AppTheme.Typography.rowCaption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Add Existing Materials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedMaterialIDs.removeAll()
                        showingExistingMaterialPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedMaterialIDs.count))") {
                        addSelectedMaterials()
                        selectedMaterialIDs.removeAll()
                        showingExistingMaterialPicker = false
                    }
                    .disabled(selectedMaterialIDs.isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleSelection(_ material: Material) {
        let id = material.persistentModelID
        if let index = selectedMaterialIDs.firstIndex(of: id) {
            selectedMaterialIDs.remove(at: index)
        } else {
            selectedMaterialIDs.append(id)
        }
    }

    private func addSelectedMaterials() {
        for id in selectedMaterialIDs {
            if let material = availableMaterials.first(where: { $0.persistentModelID == id }) {
                addExistingMaterial(material)
            }
        }
    }

    private func addExistingMaterial(_ material: Material) {
        let link = ProductMaterial(
            product: product,
            material: material,
            sortOrder: product.productMaterials.count,
            unitsRequiredPerProduct: material.defaultUnitsPerProduct
        )
        modelContext.insert(link)
        product.productMaterials.append(link)
        material.productMaterials.append(link)
    }

    private func moveMaterial(at index: Int, direction: Int) {
        let targetIndex = index + direction
        var links = sortedLinks
        guard targetIndex >= 0, targetIndex < links.count else { return }
        links.swapAt(index, targetIndex)
        for (i, link) in links.enumerated() {
            link.sortOrder = i
        }
    }

    private func removeLink(_ link: ProductMaterial) {
        let linkID = link.persistentModelID
        modelContext.delete(link)
        linkToRemove = nil

        let remaining = product.productMaterials
            .filter { $0.persistentModelID != linkID }
            .sorted { $0.sortOrder < $1.sortOrder }
        for (index, remainingLink) in remaining.enumerated() {
            remainingLink.sortOrder = index
        }
    }
}
