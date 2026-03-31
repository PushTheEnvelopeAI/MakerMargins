// WorkStep.swift
// MakerMargins
//
// A single labour step that can be shared across multiple products.
// WorkSteps are independent entities — they are NOT owned by a single product.
// The ProductWorkStep join model links steps to products with per-product ordering.
//
// Core batch-tracking fields:
//   recordedTime          — total seconds elapsed for the timed batch
//   batchUnitsCompleted   — how many finished units came out of that batch
//
// CostingEngine derives:
//   unitTimeHours  = (recordedTime / batchUnitsCompleted) / 3600

import Foundation
import SwiftData

@Model
final class WorkStep {
    var title: String
    var summary: String         // named 'summary' to avoid conflict with NSObject.description
    var image: Data?

    /// Total elapsed seconds for the recorded batch run. Set by StopwatchView.
    var recordedTime: TimeInterval

    /// Number of finished units produced during the recorded batch run.
    var batchUnitsCompleted: Decimal

    /// Display label for the unit of work (e.g. "piece", "board", "item").
    var unitName: String

    /// Default number of times this step is performed per finished product.
    /// Pre-fills ProductWorkStep.unitsRequiredPerProduct when linking to a product.
    @Attribute(originalName: "unitsRequiredPerProduct")
    var defaultUnitsPerProduct: Decimal

    // MARK: Relationship

    /// Join entries linking this step to products. Cascade-deleted when the step is deleted.
    @Relationship(deleteRule: .cascade)
    var productWorkSteps: [ProductWorkStep] = []

    init(
        title: String,
        summary: String = "",
        image: Data? = nil,
        recordedTime: TimeInterval = 0,
        batchUnitsCompleted: Decimal = 1,
        unitName: String = "unit",
        defaultUnitsPerProduct: Decimal = 1
    ) {
        self.title = title
        self.summary = summary
        self.image = image
        self.recordedTime = recordedTime
        self.batchUnitsCompleted = batchUnitsCompleted
        self.unitName = unitName
        self.defaultUnitsPerProduct = defaultUnitsPerProduct
    }
}
