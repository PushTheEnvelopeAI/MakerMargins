// ProductMaterial.swift
// MakerMargins
//
// Join model linking a Material to a Product with per-product ordering.
// Enables many-to-many: one Material can be reused across multiple Products.
//
// Cascade rules:
//   Deleting a Product cascade-deletes its ProductMaterial entries (associations)
//   but does NOT delete the Material itself — it remains in the material library.
//   Deleting a Material cascade-deletes its ProductMaterial entries.

import Foundation
import SwiftData

@Model
final class ProductMaterial {

    /// The product this association belongs to.
    var product: Product?

    /// The shared material being linked.
    var material: Material?

    /// Display order of this material within the product's material list. Zero-based.
    var sortOrder: Int

    // MARK: Sync-readiness (Epic 7)
    var remoteID: UUID? = nil
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// How many units of this material are consumed per finished product.
    /// Per-product override — pre-filled from Material.defaultUnitsPerProduct on creation.
    var unitsRequiredPerProduct: Decimal = 1

    init(
        product: Product? = nil,
        material: Material? = nil,
        sortOrder: Int = 0,
        unitsRequiredPerProduct: Decimal = 1
    ) {
        self.product = product
        self.material = material
        self.sortOrder = sortOrder
        self.unitsRequiredPerProduct = unitsRequiredPerProduct
    }
}
