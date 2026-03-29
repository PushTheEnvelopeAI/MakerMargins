// CostingEngine.swift
// MakerMargins
//
// Central calculation handler for all costing and pricing logic.
// Pure logic — no state, no UI. Models are pure data; this is pure math.
//
// Model-based functions accept WorkStep/Product objects for use in views.
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
            unitsRequiredPerProduct: step.unitsRequiredPerProduct,
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

    // MARK: - Product-Level Calculations

    /// Total labor cost across all work steps linked to a product.
    /// Traverses ProductWorkStep join entries to reach each shared WorkStep.
    static func totalLaborCost(product: Product) -> Decimal {
        product.productWorkSteps.compactMap(\.workStep).reduce(Decimal.zero) { sum, step in
            sum + stepLaborCost(step: step)
        }
    }

    /// Total material cost across all materials for a product.
    /// Stub — full implementation in Epic 3.
    static func totalMaterialCost(product: Product) -> Decimal {
        0
    }

    /// Total production cost with buffers applied.
    /// (labor + material + shipping) * (1 + materialBuffer + laborBuffer)
    static func totalProductionCost(product: Product) -> Decimal {
        let labor = totalLaborCost(product: product)
        let material = totalMaterialCost(product: product)
        let base = labor + material + product.shippingCost
        let bufferMultiplier = 1 + product.materialBuffer + product.laborBuffer
        return base * bufferMultiplier
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
