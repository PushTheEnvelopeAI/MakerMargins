// ProductDetailView.swift
// MakerMargins
//
// Scrollable hub for a single Product.
// Epic 1: header, cost summary card, and placeholder sections for labor and materials.
// Labor section is wired in Epic 2; Materials in Epic 3.

import SwiftUI
import SwiftData

struct ProductDetailView: View {
    let product: Product

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditForm = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                headerSection
                ProductCostSummaryCard(product: product)
                    .padding(.horizontal)
                laborSection
                materialsSection
            }
            .padding(.vertical)
        }
        .navigationTitle(product.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit Product") {
                        showingEditForm = true
                    }
                    Divider()
                    Button("Delete Product", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            ProductFormView(product: product)
        }
        .confirmationDialog(
            "Delete \"\(product.title)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Product", role: .destructive) {
                modelContext.delete(product)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will also delete all work steps and materials for this product. This action cannot be undone.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if let data = product.image, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: AppTheme.Sizing.detailImageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
                    .padding(.horizontal)
            } else {
                PlaceholderImageView(
                    height: AppTheme.Sizing.detailPlaceholderHeight,
                    cornerRadius: AppTheme.CornerRadius.large,
                    iconFont: .largeTitle
                )
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let category = product.category {
                    Text(category.name)
                        .font(AppTheme.Typography.badge)
                        .padding(.horizontal, 10)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(AppTheme.Colors.accentSubtle, in: Capsule())
                        .foregroundStyle(AppTheme.Colors.accent)
                }
                if !product.summary.isEmpty {
                    Text(product.summary)
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }

    private var laborSection: some View {
        GroupBox("Labor") {
            HStack {
                Text("Add work steps to calculate labor costs")
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .padding(.horizontal)
    }

    private var materialsSection: some View {
        GroupBox("Materials") {
            HStack {
                Text("Add materials to calculate material costs")
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .padding(.horizontal)
    }
}
