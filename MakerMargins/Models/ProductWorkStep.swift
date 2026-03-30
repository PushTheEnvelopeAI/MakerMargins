// ProductWorkStep.swift
// MakerMargins
//
// Join model linking a WorkStep to a Product with per-product ordering.
// Enables many-to-many: one WorkStep can be reused across multiple Products.
//
// Cascade rules:
//   Deleting a Product cascade-deletes its ProductWorkStep entries (associations)
//   but does NOT delete the WorkStep itself — it remains in the step library.
//   Deleting a WorkStep cascade-deletes its ProductWorkStep entries.

import Foundation
import SwiftData

@Model
final class ProductWorkStep {

    /// The product this association belongs to.
    var product: Product?

    /// The shared work step being linked.
    var workStep: WorkStep?

    /// Display order of this step within the product's workflow. Zero-based.
    var sortOrder: Int

    /// How many units of this step are required per finished product.
    /// Per-product override — pre-filled from WorkStep.defaultUnitsPerProduct on creation.
    var unitsRequiredPerProduct: Decimal = 1

    init(
        product: Product? = nil,
        workStep: WorkStep? = nil,
        sortOrder: Int = 0,
        unitsRequiredPerProduct: Decimal = 1
    ) {
        self.product = product
        self.workStep = workStep
        self.sortOrder = sortOrder
        self.unitsRequiredPerProduct = unitsRequiredPerProduct
    }
}
