// ProductFormView.swift
// MakerMargins
//
// Create / edit sheet for a Product.
// Pass nil to create a new product; pass an existing Product to edit it.
// All fields are held in local @State — never bound directly to the model —
// so changes only persist when the user taps Save.
//
// Buffer fields display as percentages (e.g. "10" for 10%).
// Values are divided by 100 on save and multiplied by 100 on load,
// so the stored Decimal fraction (0.10) never leaks into the UI.

import SwiftUI
import SwiftData
import PhotosUI

struct ProductFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.name) private var categories: [Category]

    let product: Product?

    // MARK: - Form state

    @State private var title: String
    @State private var summary: String
    @State private var shippingCostText: String
    @State private var materialBufferText: String  // displayed as %, stored as fraction
    @State private var laborBufferText: String      // displayed as %, stored as fraction
    @State private var selectedCategory: Category?

    // Image
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil

    // MARK: - Init

    init(product: Product?) {
        self.product = product
        _title = State(initialValue: product?.title ?? "")
        _summary = State(initialValue: product?.summary ?? "")
        _shippingCostText = State(initialValue: product.map { "\($0.shippingCost)" } ?? "0")
        // Convert stored fraction → percentage for display
        _materialBufferText = State(initialValue: product.map { "\($0.materialBuffer * 100)" } ?? "0")
        _laborBufferText    = State(initialValue: product.map { "\($0.laborBuffer * 100)" } ?? "0")
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
                basicInfoSection
                imageSection
                categorySection
                costSection
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
        Section("Details") {
            TextField("Title", text: $title)
            TextField("Description", text: $summary, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var imageSection: some View {
        // Hoist to a Sendable String before the PhotosPicker closure —
        // PhotosUI's label ViewBuilder is @Sendable in the iOS 18 SDK, so
        // Swift 6 rejects accessing @MainActor @State from inside it directly.
        let pickerLabel = imageData == nil ? "Choose Image" : "Change Image"
        return Section("Image") {
            if let data = imageData, let uiImage = UIImage(data: data) {
                HStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Button("Remove", role: .destructive) {
                        imageData = nil
                        photoItem = nil
                    }
                    .buttonStyle(.borderless)
                }
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(pickerLabel, systemImage: "photo")
            }
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

    private var costSection: some View {
        Section("Cost Inputs") {
            LabeledContent("Shipping Cost") {
                TextField("0.00", text: $shippingCostText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Material Buffer") {
                HStack(spacing: 4) {
                    TextField("0", text: $materialBufferText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("%")
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("Labor Buffer") {
                HStack(spacing: 4) {
                    TextField("0", text: $laborBufferText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("%")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func save() {
        let shipping = Decimal(string: shippingCostText) ?? 0
        // Convert percentage input back to fraction for storage
        let materialBuf = (Decimal(string: materialBufferText) ?? 0) / 100
        let laborBuf    = (Decimal(string: laborBufferText) ?? 0) / 100
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespaces)

        if let product {
            product.title = trimmedTitle
            product.summary = trimmedSummary
            product.shippingCost = shipping
            product.materialBuffer = materialBuf
            product.laborBuffer = laborBuf
            product.category = selectedCategory
            product.image = imageData
        } else {
            let newProduct = Product(
                title: trimmedTitle,
                summary: trimmedSummary,
                image: imageData,
                shippingCost: shipping,
                materialBuffer: materialBuf,
                laborBuffer: laborBuf,
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
