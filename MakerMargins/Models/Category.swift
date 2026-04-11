// Category.swift
// MakerMargins
//
// Organises products into named groups (e.g. "Cutting Boards", "Jewelry").
// One Category → many Products. Deleting a Category nullifies the category
// on its products — it does NOT delete the products themselves.

import Foundation
import SwiftData

@Model
final class Category {
    var name: String

    // MARK: Sync-readiness (Epic 7)
    var remoteID: UUID? = nil
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // Inverse of Product.category. Delete rule: .nullify (default) —
    // orphaned products keep their data, their category becomes nil.
    var products: [Product] = []

    init(name: String) {
        self.name = name
    }
}
