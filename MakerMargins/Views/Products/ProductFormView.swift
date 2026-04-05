// ProductFormView.swift
// MakerMargins
//
// Create / edit sheet for a Product.
// Pass nil to create a new product; pass an existing Product to edit it.
// All fields are held in local @State — never bound directly to the model —
// so changes only persist when the user taps Save.
//
// Cost fields (shipping, buffers) are intentionally omitted — they are
// edited from ProductDetailView after the product is created.

import SwiftUI
import SwiftData
import PhotosUI

struct ProductFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.name) private var categories: [Category]

    let product: Product?
    var onCreate: ((Product) -> Void)?

    // MARK: - Form state

    @State private var title: String
    @State private var sku: String
    @State private var summary: String
    @State private var selectedCategory: Category?

    // Image
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil

    // Inline category creation
    @State private var isCreatingCategory = false
    @State private var newCategoryName: String = ""
    @State private var categoryToDelete: Category?
    @FocusState private var isFieldFocused: Bool
    @State private var titleHasBeenTouched = false

    // MARK: - Init

    init(product: Product?, onCreate: ((Product) -> Void)? = nil) {
        self.product = product
        self.onCreate = onCreate
        _title = State(initialValue: product?.title ?? "")
        _sku = State(initialValue: product?.sku ?? "")
        _summary = State(initialValue: product?.summary ?? "")
        _selectedCategory = State(initialValue: product?.category)
        _imageData = State(initialValue: product?.image)
    }

    // MARK: - Validation

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                PhotoPickerSection(imageData: $imageData, photoItem: $photoItem)
                basicInfoSection
                categorySection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(product == nil ? "New Product" : "Edit Product")
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
                    Button("Done") { isFieldFocused = false }
                }
            }
            .onChange(of: photoItem) { _, newItem in
                loadPhoto(from: newItem)
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    private var hasUnsavedChanges: Bool {
        if product != nil {
            return title != (product?.title ?? "")
                || sku != (product?.sku ?? "")
                || summary != (product?.summary ?? "")
                || selectedCategory?.persistentModelID != product?.category?.persistentModelID
                || imageData != product?.image
        } else {
            return !title.trimmingCharacters(in: .whitespaces).isEmpty
                || !sku.trimmingCharacters(in: .whitespaces).isEmpty
                || !summary.trimmingCharacters(in: .whitespaces).isEmpty
                || selectedCategory != nil
                || imageData != nil
        }
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                TextField("Title", text: $title)
                    .focused($isFieldFocused)
                    .onChange(of: isFieldFocused) { _, focused in
                        if focused { titleHasBeenTouched = true }
                    }
                if titleHasBeenTouched && title.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Title is required")
                        .font(AppTheme.Typography.rowCaption)
                        .foregroundStyle(AppTheme.Colors.destructive)
                }
            }
            TextField("SKU", text: $sku)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                TextField("Description", text: $summary, axis: .vertical)
                    .lineLimit(3...6)
                Text("A short summary to help identify this product")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
        } header: {
            Text("Details")
        }
    }

    private var categorySection: some View {
        Section {
            Button {
                selectedCategory = nil
            } label: {
                HStack {
                    Text("None")
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedCategory == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                }
            }
            .buttonStyle(.plain)

            ForEach(categories) { category in
                Button {
                    selectedCategory = category
                } label: {
                    HStack {
                        Text(category.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedCategory?.persistentModelID == category.persistentModelID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.Colors.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        categoryToDelete = category
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if isCreatingCategory {
                HStack {
                    TextField("Category name", text: $newCategoryName)
                    Button("Add") {
                        createCategory()
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") {
                        isCreatingCategory = false
                        newCategoryName = ""
                    }
                    .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    isCreatingCategory = true
                } label: {
                    Label("New Category", systemImage: "plus.circle")
                }
            }
        } header: {
            Text("Category")
        } footer: {
            Text("Group products by category for easy filtering")
        }
        .confirmationDialog(
            "Delete Category",
            isPresented: Binding(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            ),
            presenting: categoryToDelete
        ) { category in
            Button("Delete", role: .destructive) {
                if selectedCategory?.persistentModelID == category.persistentModelID {
                    selectedCategory = nil
                }
                modelContext.delete(category)
                categoryToDelete = nil
            }
        } message: { category in
            Text("Remove \"\(category.name)\"? Products in this category will become uncategorized but won't be deleted.")
        }
    }

    private func createCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let category = Category(name: name)
        modelContext.insert(category)
        selectedCategory = category
        newCategoryName = ""
        isCreatingCategory = false
    }

    // MARK: - Actions

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedSku = sku.trimmingCharacters(in: .whitespaces)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespaces)

        if let product {
            product.title = trimmedTitle
            product.sku = trimmedSku
            product.summary = trimmedSummary
            product.category = selectedCategory
            product.image = imageData
        } else {
            let newProduct = Product(
                title: trimmedTitle,
                sku: trimmedSku,
                summary: trimmedSummary,
                image: imageData,
                category: selectedCategory
            )
            modelContext.insert(newProduct)
            onCreate?(newProduct)
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
