// Product.swift
// MakerMargins
//
// A maker's SKU — the central entity of the app.
// Links to shared WorkSteps via ProductWorkStep and shared Materials via ProductMaterial.
// Deleting a Product cascades to its ProductWorkStep and ProductMaterial associations.
// WorkSteps and Materials themselves are shared and survive product deletion.

import Foundation
import SwiftData

@Model
final class Product {
    var title: String
    var summary: String         // named 'summary' to avoid conflict with NSObject.description
    var image: Data?

    /// Per-unit shipping cost in the user's chosen currency.
    var shippingCost: Decimal

    /// Overhead buffer applied to material costs. Stored as a fraction: 0.10 = 10%.
    var materialBuffer: Decimal

    /// Overhead buffer applied to labour costs. Stored as a fraction: 0.05 = 5%.
    var laborBuffer: Decimal

    // MARK: Relationships

    /// The category this product belongs to. Optional — products can be uncategorised.
    var category: Category?

    /// Join entries linking shared WorkSteps to this product. Cascade-deleted with the product
    /// (removes associations only — the WorkSteps themselves survive in the step library).
    @Relationship(deleteRule: .cascade)
    var productWorkSteps: [ProductWorkStep] = []

    /// Join entries linking shared Materials to this product. Cascade-deleted with the product
    /// (removes associations only — the Materials themselves survive in the material library).
    @Relationship(deleteRule: .cascade)
    var productMaterials: [ProductMaterial] = []

    /// Per-platform pricing overrides for this product. Cascade-deleted with the product.
    /// Up to 4 entries (one per PlatformType), created lazily from PlatformFeeProfile defaults.
    @Relationship(deleteRule: .cascade)
    var productPricings: [ProductPricing] = []

    init(
        title: String,
        summary: String = "",
        image: Data? = nil,
        shippingCost: Decimal = 0,
        materialBuffer: Decimal = 0,
        laborBuffer: Decimal = 0,
        category: Category? = nil
    ) {
        self.title = title
        self.summary = summary
        self.image = image
        self.shippingCost = shippingCost
        self.materialBuffer = materialBuffer
        self.laborBuffer = laborBuffer
        self.category = category
    }
}
