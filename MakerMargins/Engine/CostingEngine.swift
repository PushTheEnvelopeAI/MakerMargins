// CostingEngine.swift
// MakerMargins
//
// Central calculation handler for all costing and pricing logic.
// Pure logic — no state, no UI. Models are pure data; this is pure math.
//
// Model-based functions accept WorkStep/Product/Material objects for use in views.
// Raw-value overloads accept primitives for real-time form previews
// before a model is saved.

import Foundation
import SwiftData

enum CostingEngine {

    // MARK: - Per-Step Calculations

    /// Hours of labor per unit produced in a batch.
    /// Returns 0 if batchUnitsCompleted is zero (division guard).
    static func unitTimeHours(step: WorkStep) -> Decimal {
        unitTimeHours(
            recordedTime: step.recordedTime,
            batchUnitsCompleted: step.batchUnitsCompleted
        )
    }

    /// Raw-value overload for form previews.
    static func unitTimeHours(
        recordedTime: TimeInterval,
        batchUnitsCompleted: Decimal
    ) -> Decimal {
        guard batchUnitsCompleted != 0 else { return 0 }
        let seconds = Decimal(recordedTime)
        return seconds / batchUnitsCompleted / 3600
    }

    /// Labor cost for a single step per finished product.
    /// stepLaborCost = unitTimeHours * unitsRequiredPerProduct * laborRate
    static func stepLaborCost(step: WorkStep) -> Decimal {
        stepLaborCost(
            recordedTime: step.recordedTime,
            batchUnitsCompleted: step.batchUnitsCompleted,
            unitsRequiredPerProduct: step.defaultUnitsPerProduct,
            laborRate: step.laborRate
        )
    }

    /// Product-context overload — uses the join model's per-product units.
    static func stepLaborCost(link: ProductWorkStep) -> Decimal {
        guard let step = link.workStep else { return 0 }
        return stepLaborCost(
            recordedTime: step.recordedTime,
            batchUnitsCompleted: step.batchUnitsCompleted,
            unitsRequiredPerProduct: link.unitsRequiredPerProduct,
            laborRate: step.laborRate
        )
    }

    /// Raw-value overload for form previews.
    static func stepLaborCost(
        recordedTime: TimeInterval,
        batchUnitsCompleted: Decimal,
        unitsRequiredPerProduct: Decimal,
        laborRate: Decimal
    ) -> Decimal {
        let hours = unitTimeHours(
            recordedTime: recordedTime,
            batchUnitsCompleted: batchUnitsCompleted
        )
        return hours * unitsRequiredPerProduct * laborRate
    }

    // MARK: - Per-Material Calculations

    /// Cost per unit of material.
    /// Returns 0 if bulkQuantity is zero (division guard).
    static func materialUnitCost(material: Material) -> Decimal {
        materialUnitCost(
            bulkCost: material.bulkCost,
            bulkQuantity: material.bulkQuantity
        )
    }

    /// Raw-value overload for form previews.
    static func materialUnitCost(
        bulkCost: Decimal,
        bulkQuantity: Decimal
    ) -> Decimal {
        guard bulkQuantity != 0 else { return 0 }
        return bulkCost / bulkQuantity
    }

    /// Cost of a single material line item per finished product.
    /// materialLineCost = materialUnitCost * unitsRequiredPerProduct
    static func materialLineCost(material: Material) -> Decimal {
        materialLineCost(
            bulkCost: material.bulkCost,
            bulkQuantity: material.bulkQuantity,
            unitsRequiredPerProduct: material.defaultUnitsPerProduct
        )
    }

    /// Product-context overload — uses the join model's per-product units.
    static func materialLineCost(link: ProductMaterial) -> Decimal {
        guard let material = link.material else { return 0 }
        return materialLineCost(
            bulkCost: material.bulkCost,
            bulkQuantity: material.bulkQuantity,
            unitsRequiredPerProduct: link.unitsRequiredPerProduct
        )
    }

    /// Raw-value overload for form previews.
    static func materialLineCost(
        bulkCost: Decimal,
        bulkQuantity: Decimal,
        unitsRequiredPerProduct: Decimal
    ) -> Decimal {
        materialUnitCost(bulkCost: bulkCost, bulkQuantity: bulkQuantity) * unitsRequiredPerProduct
    }

    // MARK: - Product-Level Calculations

    /// Total labor cost across all work steps linked to a product.
    /// Uses per-product unitsRequiredPerProduct from each join model.
    static func totalLaborCost(product: Product) -> Decimal {
        product.productWorkSteps.reduce(Decimal.zero) { sum, link in
            sum + stepLaborCost(link: link)
        }
    }

    /// Total material cost across all materials linked to a product.
    /// Uses per-product unitsRequiredPerProduct from each join model.
    static func totalMaterialCost(product: Product) -> Decimal {
        product.productMaterials.reduce(Decimal.zero) { sum, link in
            sum + materialLineCost(link: link)
        }
    }

    /// Total labor cost with the product's labor buffer applied.
    static func totalLaborCostBuffered(product: Product) -> Decimal {
        totalLaborCost(product: product) * (1 + product.laborBuffer)
    }

    /// Total material cost with the product's material buffer applied.
    static func totalMaterialCostBuffered(product: Product) -> Decimal {
        totalMaterialCost(product: product) * (1 + product.materialBuffer)
    }

    /// Total production cost with per-section buffers applied.
    /// labor × (1 + laborBuffer) + material × (1 + materialBuffer) + shipping
    /// Shipping is never buffered.
    static func totalProductionCost(product: Product) -> Decimal {
        let laborBuffered = totalLaborCostBuffered(product: product)
        let materialBuffered = totalMaterialCostBuffered(product: product)
        return laborBuffered + materialBuffered + product.shippingCost
    }

    // MARK: - Time Formatting

    /// Formats a duration in seconds to a human-readable string.
    /// Examples: "1h 23m 45s", "5m 30s", "0m 0s"
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if h > 0 {
            return "\(h)h \(m)m \(s)s"
        }
        return "\(m)m \(s)s"
    }
}
