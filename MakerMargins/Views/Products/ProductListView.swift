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
                    .padding(.top, AppTheme.Spacing.sm)
            }

            if filteredProducts.isEmpty {
                emptyState
                    .padding(.top, 40)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: AppTheme.Spacing.lg),
                        GridItem(.flexible())
                    ],
                    spacing: AppTheme.Spacing.lg
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
            HStack(spacing: AppTheme.Spacing.sm) {
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
                .font(isSelected ? AppTheme.Typography.sectionHeader : AppTheme.Typography.bodyText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected ? AppTheme.Colors.accent : AppTheme.Colors.chipBackground,
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
                .fill(AppTheme.Colors.placeholder)
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
        HStack(spacing: AppTheme.Spacing.md) {
            ProductThumbnailView(
                imageData: product.image,
                size: CGSize(width: AppTheme.Sizing.thumbnailSmall, height: AppTheme.Sizing.thumbnailSmall),
                cornerRadius: AppTheme.CornerRadius.small
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(product.title)
                    .font(AppTheme.Typography.rowTitle)
                if let category = product.category {
                    Text(category.name)
                        .font(AppTheme.Typography.rowCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}

// MARK: - ProductGridCell

private struct ProductGridCell: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            gridThumbnail

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(product.title)
                    .font(AppTheme.Typography.gridTitle)
                    .lineLimit(2)
                // Always render category line to keep cells uniform height.
                Text(product.category?.name ?? " ")
                    .font(AppTheme.Typography.gridCaption)
                    .foregroundStyle(product.category != nil ? Color.secondary : Color.clear)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppTheme.Spacing.sm)

            Spacer(minLength: 0)
        }
        .padding(.bottom, AppTheme.Spacing.sm)
        .frame(height: AppTheme.Sizing.gridCellHeight)
        .cardStyle()
    }

    @ViewBuilder
    private var gridThumbnail: some View {
        let clip = UnevenRoundedRectangle(
            topLeadingRadius: AppTheme.CornerRadius.medium,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: AppTheme.CornerRadius.medium
        )
        if let data = product.image, let uiImage = UIImage(data: data) {
            Color.clear
                .frame(height: AppTheme.Sizing.gridImageHeight)
                .overlay {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(clip)
        } else {
            Rectangle()
                .fill(AppTheme.Colors.placeholder)
                .frame(height: AppTheme.Sizing.gridImageHeight)
                .clipShape(clip)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
        }
    }
}
