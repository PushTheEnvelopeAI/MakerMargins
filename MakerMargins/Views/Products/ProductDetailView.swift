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
            VStack(alignment: .leading, spacing: 20) {
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
        VStack(alignment: .leading, spacing: 12) {
            if let data = product.image, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemFill))
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let category = product.category {
                    Text(category.name)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                if !product.summary.isEmpty {
                    Text(product.summary)
                        .font(.subheadline)
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
    }

    private var materialsSection: some View {
        GroupBox("Materials") {
            HStack {
                Text("Add materials to calculate material costs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
    }
}
