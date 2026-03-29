// CategoryListView.swift
// MakerMargins
//
// Displays all Categories sorted by name.
// Accessible from Settings. Allows creation, editing, and deletion.
// Deleting a Category nullifies its products' category reference (no products are deleted).

import SwiftUI
import SwiftData

struct CategoryListView: View {
    @Query(sort: \Category.name) private var categories: [Category]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme

    @State private var showingCreateForm = false
    @State private var editingCategory: Category? = nil

    var body: some View {
        List {
            ForEach(categories) { category in
                Button {
                    editingCategory = category
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .foregroundStyle(theme.textPrimary)
                            Text("\(category.products.count) product\(category.products.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .onDelete(perform: deleteCategories)
        }
        .overlay {
            if categories.isEmpty {
                ContentUnavailableView(
                    "No Categories",
                    systemImage: "tag",
                    description: Text("Tap + to create your first category.")
                )
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingCreateForm) {
            CategoryFormView(category: nil)
        }
        .sheet(item: $editingCategory) { category in
            CategoryFormView(category: category)
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }
}
