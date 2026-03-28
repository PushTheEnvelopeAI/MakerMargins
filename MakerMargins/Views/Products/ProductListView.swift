// ProductListView.swift
// MakerMargins
//
// Tab 1 root. Displays all Products in a switchable list or grid.
// Supports text search by title and filtering by category chip.
// Entry point for creating products and navigating to ProductDetailView.

import SwiftUI
import SwiftData

struct ProductListView: View {
    @Query(sort: \Product.title) private var products: [Product]
    @Query(sort: \Category.name) private var categories: [Category]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedCategory: Category? = nil
    @State private var isGridMode = false
    @State private var showingCreateForm = false
    @State private var productToDelete: Product? = nil

    // MARK: - Filtering

    private var filteredProducts: [Product] {
        products.filter { product in
            let matchesSearch = searchText.isEmpty ||
                product.title.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil ||
                product.category?.persistentModelID == selectedCategory?.persistentModelID
            return matchesSearch && matchesCategory
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isGridMode {
                gridContent
            } else {
                listContent
            }
        }
        .navigationTitle("Products")
        .searchable(text: $searchText, prompt: "Search products")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isGridMode.toggle()
                } label: {
                    Image(systemName: isGridMode ? "list.bullet" : "square.grid.2x2")
                }
            }
        }
        .sheet(isPresented: $showingCreateForm) {
            ProductFormView(product: nil)
        }
        .navigationDestination(for: Product.self) { product in
            ProductDetailView(product: product)
        }
        .confirmationDialog(
            "Delete \"\(productToDelete?.title ?? "")\"?",
            isPresented: Binding(
                get: { productToDelete != nil },
                set: { if !$0 { productToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Product", role: .destructive) {
                if let product = productToDelete {
                    modelContext.delete(product)
                    productToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { productToDelete = nil }
        } message: {
            Text("This will also delete all work steps and materials. This action cannot be undone.")
        }
    }

    // MARK: - List

    private var listContent: some View {
        List {
            if !categories.isEmpty {
                categoryChips
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if filteredProducts.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(filteredProducts) { product in
                    NavigationLink(value: product) {
                        ProductRowView(product: product)
                    }
                }
                .onDelete { offsets in
                    if let index = offsets.first {
                        productToDelete = filteredProducts[index]
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Grid

    private var gridContent: some View {
        ScrollView {
            if !categories.isEmpty {
                categoryChips
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            if filteredProducts.isEmpty {
                emptyState
                    .padding(.top, 40)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(filteredProducts) { product in
                        NavigationLink(value: product) {
                            ProductGridCell(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    // MARK: - Category chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(categories) { category in
                    chip(label: category.name,
                         isSelected: category.persistentModelID == selectedCategory?.persistentModelID) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected ? Color.accentColor : Color(.secondarySystemFill),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        if products.isEmpty {
            ContentUnavailableView(
                "No Products Yet",
                systemImage: "square.grid.2x2",
                description: Text("Tap + to add your first product.")
            )
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}

// MARK: - ProductThumbnailView

private struct ProductThumbnailView: View {
    let imageData: Data?
    let size: CGSize
    let cornerRadius: CGFloat

    var body: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(.secondarySystemFill))
                .frame(width: size.width, height: size.height)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.tertiary)
                }
        }
    }
}

// MARK: - ProductRowView

private struct ProductRowView: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnailView(
                imageData: product.image,
                size: CGSize(width: 48, height: 48),
                cornerRadius: 8
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(product.title)
                    .font(.body)
                if let category = product.category {
                    Text(category.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ProductGridCell

private struct ProductGridCell: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            gridThumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(product.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                if let category = product.category {
                    Text(category.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // Grid cells need a full-width variable-height image with uneven corners,
    // so this uses a bespoke layout rather than ProductThumbnailView.
    @ViewBuilder
    private var gridThumbnail: some View {
        let clip = UnevenRoundedRectangle(
            topLeadingRadius: 14, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 14
        )
        if let data = product.image, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipShape(clip)
        } else {
            Rectangle()
                .fill(Color(.tertiarySystemFill))
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipShape(clip)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
        }
    }
}
