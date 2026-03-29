// CategoryFormView.swift
// MakerMargins
//
// Create / edit sheet for a Category.
// Pass nil to create a new category; pass an existing Category to edit it.

import SwiftUI
import SwiftData

struct CategoryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    /// The category being edited. Nil means we are creating a new one.
    let category: Category?

    @State private var name: String = ""

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(category: Category?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category name", text: $name)
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
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
        }
    }

    private func save() {
        if let category {
            category.name = name.trimmingCharacters(in: .whitespaces)
        } else {
            let newCategory = Category(name: name.trimmingCharacters(in: .whitespaces))
            modelContext.insert(newCategory)
        }
        dismiss()
    }
}
