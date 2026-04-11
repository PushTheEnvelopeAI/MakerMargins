// Material.swift
// MakerMargins
//
// A raw material input used in producing products.
// Materials are shared entities — they can be reused across multiple products
// via the ProductMaterial join model. Editing a material from any context
// updates it everywhere.
//
// Bulk purchase fields:
//   bulkCost        — total cost paid for the bulk supply
//   bulkQuantity    — number of units in that supply
//
// CostingEngine derives:
//   materialUnitCost  = bulkCost / bulkQuantity
//   materialLineCost  = materialUnitCost * unitsRequiredPerProduct (from join model)

import Foundation
import SwiftData

@Model
final class Material {
    var title: String
    var summary: String         // named 'summary' to avoid conflict with NSObject.description
    var image: Data?

    /// Optional supplier URL for this material.
    var link: String

    /// Total cost of the bulk purchase in the user's chosen currency.
    var bulkCost: Decimal

    /// Number of units contained in the bulk purchase (e.g. 32 oz, 10 board-feet).
    var bulkQuantity: Decimal

    /// Display label for the unit of measure (e.g. "oz", "board-foot", "sheet").
    var unitName: String

    /// Default number of units consumed per finished product.
    /// Pre-fills ProductMaterial.unitsRequiredPerProduct when linking to a product.
    @Attribute(originalName: "unitsRequiredPerProduct")
    var defaultUnitsPerProduct: Decimal

    // MARK: Sync-readiness (Epic 7)
    var remoteID: UUID? = nil
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // MARK: Relationship

    /// Join entries linking this material to products. Cascade-deleted when the material is deleted
    /// (removes associations only — the Products themselves survive).
    @Relationship(deleteRule: .cascade)
    var productMaterials: [ProductMaterial] = []

    init(
        title: String,
        summary: String = "",
        image: Data? = nil,
        link: String = "",
        bulkCost: Decimal = 0,
        bulkQuantity: Decimal = 1,
        unitName: String = "unit",
        defaultUnitsPerProduct: Decimal = 1
    ) {
        self.title = title
        self.summary = summary
        self.image = image
        self.link = link
        self.bulkCost = bulkCost
        self.bulkQuantity = bulkQuantity
        self.unitName = unitName
        self.defaultUnitsPerProduct = defaultUnitsPerProduct
    }
}
