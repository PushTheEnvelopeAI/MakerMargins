// CostingEngine.swift
// MakerMargins
//
// Central calculation handler for all costing and pricing logic.
//
// Implements:
//   - unitTimeHours(step:)             -> recordedTime / batchUnitsCompleted / 3600
//   - stepLaborCost(step:)             -> unitTimeHours * unitsRequiredPerProduct * laborRate
//   - totalLaborCost(product:)         -> sum of stepLaborCost across all WorkSteps
//   - materialUnitCost(material:)      -> bulkCost / bulkQuantity
//   - materialLineCost(material:)      -> materialUnitCost * unitsRequiredPerProduct
//   - totalMaterialCost(product:)      -> sum of materialLineCost across all Materials
//   - totalProductionCost(product:)    -> (labor + material + shipping) * (1 + buffers)
//   - targetRetailPrice(product:platform:) -> totalProductionCost / (1 - (fees + margin))
//
// All monetary values use Decimal. TimeInterval division uses Double then converts.
// Epic 0 — placeholder. Full implementation in Epic 2.
