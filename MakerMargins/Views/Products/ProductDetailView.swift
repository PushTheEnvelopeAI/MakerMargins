// ProductDetailView.swift
// MakerMargins
//
// Scrollable hub for a single Product.
// Epic 1: header, cost summary card, materials placeholder.
// Epic 2: live labor section via WorkStepListView, navigation to WorkStepDetailView.

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
        .appBackground()
        .navigationDestination(for: WorkStep.self) { step in
            WorkStepDetailView(step: step, product: product)
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
            Text("This will also delete all materials for this product. Work steps will be preserved in the step library. This action cannot be undone.")
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
                        .background(AppTheme.Colors.categoryBadgeBackground, in: Capsule())
                        .foregroundStyle(AppTheme.Colors.categoryBadge)
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
        WorkStepListView(product: product)
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
