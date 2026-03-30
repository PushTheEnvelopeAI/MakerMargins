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
    @State private var summary: String
    @State private var selectedCategory: Category?

    // Image
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil

    // Inline category creation
    @State private var isCreatingCategory = false
    @State private var newCategoryName: String = ""

    // MARK: - Init

    init(product: Product?) {
        self.product = product
        _title = State(initialValue: product?.title ?? "")
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
            }
            .onChange(of: photoItem) { _, newItem in
                loadPhoto(from: newItem)
            }
        }
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        Section {
            TextField("Title", text: $title)
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
                        if selectedCategory?.persistentModelID == category.persistentModelID {
                            selectedCategory = nil
                        }
                        modelContext.delete(category)
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
        let trimmedSummary = summary.trimmingCharacters(in: .whitespaces)

        if let product {
            product.title = trimmedTitle
            product.summary = trimmedSummary
            product.category = selectedCategory
            product.image = imageData
        } else {
            let newProduct = Product(
                title: trimmedTitle,
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
