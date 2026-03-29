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
    @Environment(\.theme) private var theme

    @Query(sort: \Category.name) private var categories: [Category]

    let product: Product?

    // MARK: - Form state

    @State private var title: String
    @State private var summary: String
    @State private var selectedCategory: Category?

    // Image
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil

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
                imageSection
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

    private var imageSection: some View {
        // Hoist all imageData reads to Sendable locals before the PhotosPicker
        // closure — PhotosUI's @ViewBuilder label is @Sendable in the iOS 18 SDK,
        // so accessing @MainActor @State directly inside it is a Swift 6 error.
        let currentImage: UIImage? = imageData.flatMap { UIImage(data: $0) }
        let hasImage = currentImage != nil
        return Section {
            PhotosPicker(selection: $photoItem, matching: .images) {
                VStack(spacing: 10) {
                    if let uiImage = currentImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(theme.fill)
                            .frame(width: 100, height: 100)
                            .overlay {
                                Image(systemName: "camera")
                                    .font(.title2)
                                    .foregroundStyle(theme.textSecondary)
                            }
                    }
                    Text(hasImage ? "Change Photo" : "Add Photo")
                        .font(.subheadline)
                        .foregroundStyle(theme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if hasImage {
                Button("Remove Photo", role: .destructive) {
                    imageData = nil
                    photoItem = nil
                }
            }
        }
    }

    private var basicInfoSection: some View {
        Section("Details") {
            TextField("Title", text: $title)
            TextField("Description", text: $summary, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $selectedCategory) {
                Text("None").tag(Optional<Category>.none)
                ForEach(categories) { category in
                    Text(category.name).tag(Optional(category))
                }
            }
        }
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
