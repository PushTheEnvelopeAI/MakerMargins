// CategoryRepository.swift
// MakerMargins
//
// Writes-only repository for Category entities.
// Reads stay on @Query. Protocol exists for future sync-layer swap.

import Foundation
import SwiftData
import SwiftUI

// MARK: - Protocol

protocol CategoryRepository {
    func create(name: String) -> Category
    func delete(_ category: Category)
}

// MARK: - SwiftData Implementation

final class SwiftDataCategoryRepository: CategoryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(name: String) -> Category {
        let category = Category(name: name)
        context.insert(category)
        return category
    }

    func delete(_ category: Category) {
        category.updatedAt = .now
        context.delete(category)
    }
}

// MARK: - Environment Key

struct CategoryRepositoryKey: EnvironmentKey {
    static let defaultValue: any CategoryRepository = PlaceholderCategoryRepository()
}

extension EnvironmentValues {
    var categoryRepository: any CategoryRepository {
        get { self[CategoryRepositoryKey.self] }
        set { self[CategoryRepositoryKey.self] = newValue }
    }
}

private struct PlaceholderCategoryRepository: CategoryRepository {
    func create(name: String) -> Category { fatalError("CategoryRepository not injected.") }
    func delete(_ category: Category) { fatalError("CategoryRepository not injected.") }
}
