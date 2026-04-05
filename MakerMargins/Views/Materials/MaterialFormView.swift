// MaterialFormView.swift
// MakerMargins
//
// Create / edit sheet for a Material.
// Pass nil to create a new material; pass an existing Material to edit it
// (changes propagate to all products using the material).
// Pass a Product to link the new material; pass nil to create a standalone library material.
// All fields are held in local @State — never bound directly to the model —
// so changes only persist when the user taps Save.

import SwiftUI
import SwiftData
import PhotosUI

struct MaterialFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyFormatter) private var currencyFormatter

    let material: Material?
    let product: Product?

    // MARK: - Form state

    @State private var title: String
    @State private var summary: String
    @State private var link: String

    // Image
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil

    // Purchase
    @State private var bulkCostText: String
    @State private var bulkQuantityText: String
    @State private var unitName: String

    // Focus tracking for select-on-tap behavior
    enum FocusableField: Hashable {
        case bulkCost, bulkQuantity, unitName
    }
    @FocusState private var focusedField: FocusableField?
    @State private var titleHasBeenTouched = false

    // MARK: - Init

    init(material: Material?, product: Product?) {
        self.material = material
        self.product = product

        _title = State(initialValue: material?.title ?? "")
        _summary = State(initialValue: material?.summary ?? "")
        _link = State(initialValue: material?.link ?? "")
        _imageData = State(initialValue: material?.image)

        _bulkCostText = State(initialValue: "\(material?.bulkCost ?? 0)")
        _bulkQuantityText = State(initialValue: "\(material?.bulkQuantity ?? 1)")
        _unitName = State(initialValue: material?.unitName ?? "unit")
    }

    // MARK: - Computed

    private var bulkCost: Decimal {
        Decimal(string: bulkCostText) ?? 0
    }

    private var bulkQuantity: Decimal {
        Decimal(string: bulkQuantityText) ?? 1
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var displayUnitName: String {
        let name = unitName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "unit" : name
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                PhotoPickerSection(imageData: $imageData, photoItem: $photoItem)
                detailsSection
                purchaseSection
                previewSection
            }
            .navigationTitle(material == nil ? "New Material" : "Edit Material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaveDisabled)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onChange(of: photoItem) { _, newItem in
                loadPhoto(from: newItem)
            }
            .onChange(of: focusedField) { oldField, newField in
                if let oldField { fieldDefault(for: oldField).restoreOnBlur() }
                if let newField { fieldDefault(for: newField).clearOnFocus() }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    private var hasUnsavedChanges: Bool {
        if material != nil {
            return title != (material?.title ?? "")
                || summary != (material?.summary ?? "")
                || link != (material?.link ?? "")
                || bulkCostText != "\(material?.bulkCost ?? 0)"
                || bulkQuantityText != "\(material?.bulkQuantity ?? 1)"
                || unitName != (material?.unitName ?? "unit")
                || imageData != material?.image
        } else {
            return !title.trimmingCharacters(in: .whitespaces).isEmpty
                || !summary.trimmingCharacters(in: .whitespaces).isEmpty
                || !link.trimmingCharacters(in: .whitespaces).isEmpty
                || imageData != nil
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section("Details") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                TextField("Title", text: $title)
                    .onTapGesture { titleHasBeenTouched = true }
                if titleHasBeenTouched && title.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Title is required")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.destructive)
                }
            }
            TextField("Description", text: $summary, axis: .vertical)
                .lineLimit(3...6)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                TextField("Supplier Link", text: $link)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Text("Optional URL to the supplier or product page")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var purchaseSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text("Bulk Cost")
                    Spacer()
                    CurrencyInputField(symbol: currencyFormatter.symbol, text: $bulkCostText)
                        .focused($focusedField, equals: .bulkCost)
                }
                Text("Total cost of the bulk purchase")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text("\(displayUnitName.capitalized)s in Purchase")
                    Spacer()
                    TextField("1", text: $bulkQuantityText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: AppTheme.Sizing.inputMedium)
                        .focused($focusedField, equals: .bulkQuantity)
                }
                Text("How many \(displayUnitName)s come in the bulk purchase")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text("Unit Name")
                    Spacer()
                    TextField("unit", text: $unitName)
                        .multilineTextAlignment(.trailing)
                        .frame(width: AppTheme.Sizing.inputLarge)
                        .focused($focusedField, equals: .unitName)
                }
                Text("What you call each piece (e.g. oz, board-foot, sheet)")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }

        } header: {
            Text("Purchase Info")
        }
    }

    private var previewSection: some View {
        Section("Calculated") {
            let unitCost = CostingEngine.materialUnitCost(
                bulkCost: bulkCost,
                bulkQuantity: bulkQuantity
            )

            VStack(spacing: AppTheme.Spacing.xs) {
                HStack {
                    Text("Cost per \(displayUnitName)")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    Text(currencyFormatter.format(unitCost))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                }
                Text("This is the key cost metric for this material")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Focus Helpers

    private func fieldDefault(for field: FocusableField) -> FormFieldDefault {
        switch field {
        case .bulkCost:
            FormFieldDefault(get: { bulkCostText }, set: { bulkCostText = $0 }, defaultValue: "0")
        case .bulkQuantity:
            FormFieldDefault(get: { bulkQuantityText }, set: { bulkQuantityText = $0 }, defaultValue: "1")
        case .unitName:
            FormFieldDefault(get: { unitName }, set: { unitName = $0 }, defaultValue: "unit")
        }
    }

    // MARK: - Actions

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespaces)
        let trimmedLink = link.trimmingCharacters(in: .whitespaces)
        let safeCost = bulkCost >= 0 ? bulkCost : 0
        let safeQuantity = bulkQuantity > 0 ? bulkQuantity : 1
        let safeUnitName = unitName.trimmingCharacters(in: .whitespaces).isEmpty ? "unit" : unitName.trimmingCharacters(in: .whitespaces)

        if let material {
            // Edit existing — changes propagate to all products using this material
            material.title = trimmedTitle
            material.summary = trimmedSummary
            material.image = imageData
            material.link = trimmedLink
            material.bulkCost = safeCost
            material.bulkQuantity = safeQuantity
            material.unitName = safeUnitName
        } else {
            // Create new material + link to product
            let newMaterial = Material(
                title: trimmedTitle,
                summary: trimmedSummary,
                image: imageData,
                link: trimmedLink,
                bulkCost: safeCost,
                bulkQuantity: safeQuantity,
                unitName: safeUnitName
            )
            modelContext.insert(newMaterial)

            if let product {
                let matLink = ProductMaterial(
                    product: product,
                    material: newMaterial,
                    sortOrder: product.productMaterials.count,
                    unitsRequiredPerProduct: newMaterial.defaultUnitsPerProduct
                )
                modelContext.insert(matLink)
                product.productMaterials.append(matLink)
                newMaterial.productMaterials.append(matLink)
            }
        }
        dismiss()
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task { @MainActor in
            imageData = try? await item.loadTransferable(type: Data.self)
        }
    }
}
