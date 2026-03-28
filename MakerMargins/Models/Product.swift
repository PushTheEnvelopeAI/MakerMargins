// Product.swift
// MakerMargins
//
// A maker's SKU — the central entity of the app.
// Owns WorkSteps (labor) and Materials (inputs). All costing rolls up here.
// Deleting a Product cascades to its WorkSteps and Materials.

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

    /// All labour steps for this product. Cascade-deleted with the product.
    @Relationship(deleteRule: .cascade)
    var workSteps: [WorkStep] = []

    /// All raw materials for this product. Cascade-deleted with the product.
    @Relationship(deleteRule: .cascade)
    var materials: [Material] = []

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
