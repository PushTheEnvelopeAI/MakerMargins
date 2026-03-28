// Material.swift
// MakerMargins
//
// A raw material input used in producing a product.
//
// Bulk purchase fields:
//   bulkCost        — total cost paid for the bulk supply
//   bulkQuantity    — number of units in that supply
//
// CostingEngine derives:
//   materialUnitCost  = bulkCost / bulkQuantity
//   materialLineCost  = materialUnitCost * unitsRequiredPerProduct

import Foundation
import SwiftData

@Model
final class Material {
    var title: String
    var summary: String         // named 'summary' to avoid conflict with NSObject.description

    /// Total cost of the bulk purchase in the user's chosen currency.
    var bulkCost: Decimal

    /// Number of units contained in the bulk purchase (e.g. 32 oz, 10 board-feet).
    var bulkQuantity: Decimal

    /// Display label for the unit of measure (e.g. "oz", "board-foot", "sheet").
    var unitName: String

    /// How many units of this material are consumed per finished product.
    var unitsRequiredPerProduct: Decimal

    // MARK: Relationship

    /// The product this material belongs to. Nil if the product has been deleted.
    var product: Product?

    init(
        title: String,
        summary: String = "",
        bulkCost: Decimal = 0,
        bulkQuantity: Decimal = 1,
        unitName: String = "unit",
        unitsRequiredPerProduct: Decimal = 1,
        product: Product? = nil
    ) {
        self.title = title
        self.summary = summary
        self.bulkCost = bulkCost
        self.bulkQuantity = bulkQuantity
        self.unitName = unitName
        self.unitsRequiredPerProduct = unitsRequiredPerProduct
        self.product = product
    }
}
