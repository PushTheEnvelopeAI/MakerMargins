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
    @Environment(\.productRepository) private var productRepository
    @Environment(\.entitlementManager) private var entitlementManager
    @Environment(\.analyticsManager) private var analyticsManager

    @State private var searchText = ""
    @State private var selectedCategory: Category? = nil
    @State private var isGridMode = false
    @State private var showingCreateForm = false
    @State private var showingTemplatePicker = false
    @State private var productToDelete: Product? = nil
    @State private var navigationPath = NavigationPath()
    @State private var newlyCreatedProduct: Product?
    @State private var navigatingFromTemplate = false
    @State private var showPaywall = false
    @State private var paywallReason: PaywallReason = .manual

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
        NavigationStack(path: $navigationPath) {
            productContent
        }
    }

    @ViewBuilder
    private var productContent: some View {
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
                Menu {
                    Button {
                        if !entitlementManager.isPro && products.count >= 3 {
                            paywallReason = .productLimit
                            showPaywall = true
                        } else {
                            showingCreateForm = true
                        }
                    } label: {
                        Label("Blank Product", systemImage: "doc")
                    }
                    Button {
                        if !entitlementManager.isPro && products.count >= 3 {
                            paywallReason = .productLimit
                            showPaywall = true
                        } else {
                            showingTemplatePicker = true
                        }
                    } label: {
                        Label("From Template", systemImage: "doc.on.doc.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create product")
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isGridMode.toggle()
                } label: {
                    Image(systemName: isGridMode ? "list.bullet" : "square.grid.2x2")
                }
                .accessibilityLabel(isGridMode ? "Switch to list view" : "Switch to grid view")
            }
        }
        .sheet(isPresented: $showingCreateForm, onDismiss: {
            if let product = newlyCreatedProduct {
                navigationPath.append(product)
                newlyCreatedProduct = nil
            }
        }) {
            ProductFormView(product: nil, onCreate: { product in
                newlyCreatedProduct = product
                analyticsManager.signal(.productCreated)
                let key = "hasSignaled_firstProductCreated"
                if !UserDefaults.standard.bool(forKey: key) {
                    UserDefaults.standard.set(true, forKey: key)
                    analyticsManager.signal(.firstProductCreated)
                }
            })
        }
        .sheet(isPresented: $showingTemplatePicker, onDismiss: {
            if let product = newlyCreatedProduct {
                navigatingFromTemplate = true
                navigationPath.append(product)
                newlyCreatedProduct = nil
            }
        }) {
            TemplatePickerView(onProductCreated: { product in
                newlyCreatedProduct = product
                analyticsManager.signal(.productCreated)
            })
        }
        .navigationDestination(for: Product.self) { product in
            ProductDetailView(product: product, skipPriceAutoSwitch: navigatingFromTemplate)
                .onDisappear { navigatingFromTemplate = false }
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
                    productRepository.delete(product)
                    productToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { productToDelete = nil }
        } message: {
            Text("This will permanently delete this product. Work steps and materials will remain in their libraries. This action cannot be undone.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: paywallReason)
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

            if !products.isEmpty {
                portfolioCard
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
                    .contextMenu {
                        Button {
                            if !entitlementManager.isPro && products.count >= 3 {
                                paywallReason = .productLimit
                                showPaywall = true
                            } else {
                                let copy = duplicateProduct(product)
                                navigationPath.append(copy)
                            }
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive) {
                            productToDelete = product
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
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
        .scrollContentBackground(.hidden)
        .appBackground()
    }

    // MARK: - Grid

    private var gridContent: some View {
        ScrollView {
            if !categories.isEmpty {
                categoryChips
                    .padding(.horizontal)
                    .padding(.top, AppTheme.Spacing.sm)
            }

            if !products.isEmpty {
                portfolioCard
                    .padding(.horizontal)
            }

            if filteredProducts.isEmpty {
                emptyState
                    .padding(.top, AppTheme.Spacing.xl * 2)
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
                            ProductGridCellView(product: product)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                if !entitlementManager.isPro && products.count >= 3 {
                                    paywallReason = .productLimit
                                    showPaywall = true
                                } else {
                                    let copy = duplicateProduct(product)
                                    navigationPath.append(copy)
                                }
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                productToDelete = product
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .appBackground()
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
            .padding(.vertical, AppTheme.Spacing.md)
        }
    }

    @ViewBuilder
    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(isSelected ? AppTheme.Typography.sectionHeader : AppTheme.Typography.bodyText)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(
                    isSelected ? AppTheme.Colors.accent : AppTheme.Colors.chipBackground,
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? AppTheme.Colors.chipSelectedForeground : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) filter")
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        if products.isEmpty {
            ContentUnavailableView {
                Label("No Products Yet", systemImage: "square.grid.2x2")
            } description: {
                Text("Track costs and calculate pricing for your products.")
            } actions: {
                Button("Start from Template") {
                    if !entitlementManager.isPro && products.count >= 3 {
                        paywallReason = .productLimit
                        showPaywall = true
                    } else {
                        showingTemplatePicker = true
                    }
                }
                    .buttonStyle(.borderedProminent)
                Button("Create Blank Product") {
                    if !entitlementManager.isPro && products.count >= 3 {
                        paywallReason = .productLimit
                        showPaywall = true
                    } else {
                        showingCreateForm = true
                    }
                }
                    .buttonStyle(.bordered)
            }
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }

    // MARK: - Portfolio Card

    private var portfolioCard: some View {
        NavigationLink {
            PortfolioView()
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.accent)
                Text("Compare your \(products.count) product\(products.count == 1 ? "" : "s")")
                    .font(AppTheme.Typography.bodyText)
                Spacer()
            }
            .padding(AppTheme.Spacing.md)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    // MARK: - Actions

    @discardableResult private func duplicateProduct(_ source: Product) -> Product {
        let copy = productRepository.duplicate(source)
        analyticsManager.signal(.productDuplicated)
        return copy
    }
}

// MARK: - ProductRowView

private struct ProductRowView: View {
    let product: Product

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ProductThumbnailView(imageData: product.image)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(product.title)
                    .font(AppTheme.Typography.rowTitle)
                HStack(spacing: AppTheme.Spacing.sm) {
                    if !product.sku.isEmpty {
                        Text(product.sku)
                            .font(AppTheme.Typography.rowCaption)
                            .foregroundStyle(.secondary)
                    }
                    if let category = product.category {
                        if !product.sku.isEmpty {
                            Text("·")
                                .foregroundStyle(.tertiary)
                        }
                        Text(category.name)
                            .font(AppTheme.Typography.rowCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}

// MARK: - ProductGridCellView

private struct ProductGridCellView: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            gridThumbnail

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(product.title)
                    .font(AppTheme.Typography.gridTitle)
                    .lineLimit(2)
                // SKU + category subtitle — always render to keep cells uniform height.
                let subtitle = [product.sku, product.category?.name ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
                Text(subtitle.isEmpty ? " " : subtitle)
                    .font(AppTheme.Typography.gridCaption)
                    .foregroundStyle(subtitle.isEmpty ? Color.clear : Color.secondary)
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
