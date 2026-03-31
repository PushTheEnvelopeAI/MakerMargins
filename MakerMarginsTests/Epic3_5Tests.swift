// Epic3_5Tests.swift
// MakerMarginsTests
//
// E2E regression tests for Epic 3.5: Item vs Product Cost Separation.
// Covers laborRate on ProductWorkStep join model, laborHoursPerProduct
// calculations, per-product rate independence, product duplication with
// laborRate, and item-level metric isolation (unitTimeHours, materialUnitCost).
//
// Each test creates its own isolated in-memory ModelContainer so tests
// never share state. Uses Swift Testing (import Testing, @Test, #expect).

import Testing
import Foundation
import SwiftData
@testable import MakerMargins

@MainActor
struct Epic3_5Tests {

    // MARK: - Helpers

    /// Returns a fresh in-memory ModelContainer with the full app schema.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Product.self,
            Category.self,
            WorkStep.self,
            Material.self,
            PlatformFeeProfile.self,
            ProductWorkStep.self,
            ProductMaterial.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Schema: laborRate on ProductWorkStep

    @Test("ProductWorkStep stores laborRate and it persists correctly")
    func productWorkStepLaborRatePersists() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Test Product")
        let step = WorkStep(title: "Test Step", recordedTime: 3600, batchUnitsCompleted: 1)
        let link = ProductWorkStep(product: product, workStep: step, sortOrder: 0, laborRate: Decimal(string: "25.00")!)

        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        try ctx.save()

        let links = try ctx.fetch(FetchDescriptor<ProductWorkStep>())
        #expect(links.count == 1)
        #expect(links[0].laborRate == Decimal(string: "25.00")!)
    }

    @Test("ProductWorkStep laborRate defaults to zero when not specified")
    func productWorkStepLaborRateDefaultsToZero() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Test Product")
        let step = WorkStep(title: "Test Step")
        let link = ProductWorkStep(product: product, workStep: step, sortOrder: 0)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        try ctx.save()

        let links = try ctx.fetch(FetchDescriptor<ProductWorkStep>())
        #expect(links[0].laborRate == 0)
    }

    // MARK: - Per-Product Rate Independence

    @Test("Same step with different laborRate per product — changes are independent")
    func perProductLaborRateIndependence() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let productA = Product(title: "Product A")
        let productB = Product(title: "Product B")
        let step = WorkStep(title: "Shared Step", recordedTime: 3600, batchUnitsCompleted: 1)

        let linkA = ProductWorkStep(product: productA, workStep: step, sortOrder: 0, laborRate: 20)
        let linkB = ProductWorkStep(product: productB, workStep: step, sortOrder: 0, laborRate: 35)

        productA.productWorkSteps.append(linkA)
        productB.productWorkSteps.append(linkB)
        step.productWorkSteps.append(linkA)
        step.productWorkSteps.append(linkB)

        ctx.insert(productA)
        ctx.insert(productB)
        ctx.insert(step)
        ctx.insert(linkA)
        ctx.insert(linkB)
        try ctx.save()

        // Change rate on Product A — should not affect Product B
        linkA.laborRate = 30
        try ctx.save()

        #expect(linkA.laborRate == 30)
        #expect(linkB.laborRate == 35)
    }

    @Test("Same step with different unitsRequiredPerProduct per product — changes are independent")
    func perProductUnitsIndependence() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let productA = Product(title: "Product A")
        let productB = Product(title: "Product B")
        let step = WorkStep(title: "Shared Step", recordedTime: 1800, batchUnitsCompleted: 2)

        let linkA = ProductWorkStep(product: productA, workStep: step, sortOrder: 0, unitsRequiredPerProduct: 1, laborRate: 20)
        let linkB = ProductWorkStep(product: productB, workStep: step, sortOrder: 0, unitsRequiredPerProduct: 4, laborRate: 20)

        productA.productWorkSteps.append(linkA)
        productB.productWorkSteps.append(linkB)
        step.productWorkSteps.append(linkA)
        step.productWorkSteps.append(linkB)

        ctx.insert(productA)
        ctx.insert(productB)
        ctx.insert(step)
        ctx.insert(linkA)
        ctx.insert(linkB)
        try ctx.save()

        // Change units on Product A — should not affect Product B
        linkA.unitsRequiredPerProduct = 3
        try ctx.save()

        #expect(linkA.unitsRequiredPerProduct == 3)
        #expect(linkB.unitsRequiredPerProduct == 4)
    }

    // MARK: - CostingEngine: laborHoursPerProduct

    @Test("laborHoursPerProduct returns correct value for known inputs")
    func laborHoursPerProductKnownValues() {
        // 3600s, 2 batch units → 0.5 hours/unit
        // 3 units/product → 0.5 × 3 = 1.5 hours/product
        let result = CostingEngine.laborHoursPerProduct(
            recordedTime: 3600,
            batchUnitsCompleted: 2,
            unitsRequiredPerProduct: 3
        )
        #expect(result == Decimal(string: "1.5")!)
    }

    @Test("laborHoursPerProduct returns zero when batchUnitsCompleted is zero")
    func laborHoursPerProductZeroGuard() {
        let result = CostingEngine.laborHoursPerProduct(
            recordedTime: 3600,
            batchUnitsCompleted: 0,
            unitsRequiredPerProduct: 2
        )
        #expect(result == 0)
    }

    @Test("laborHoursPerProduct model overload uses join model's unitsRequiredPerProduct")
    func laborHoursPerProductModelOverload() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Test Product")
        // 7200s, 4 batch units → 0.5 hours/unit
        let step = WorkStep(title: "Test Step", recordedTime: 7200, batchUnitsCompleted: 4)
        // 2 units/product → 0.5 × 2 = 1.0 hours/product
        let link = ProductWorkStep(product: product, workStep: step, sortOrder: 0, unitsRequiredPerProduct: 2, laborRate: 15)

        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        try ctx.save()

        let result = CostingEngine.laborHoursPerProduct(link: link)
        #expect(result == Decimal(string: "1")!)
    }

    // MARK: - CostingEngine: stepLaborCost uses link.laborRate

    @Test("stepLaborCost(link:) uses laborRate from the join model, not from the step")
    func stepLaborCostUsesLinkLaborRate() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Test Product")
        // 3600s, 1 batch unit → 1 hour/unit
        let step = WorkStep(title: "Test Step", recordedTime: 3600, batchUnitsCompleted: 1)
        // 1 unit/product, $25/hr → 1 × 1 × 25 = $25
        let link = ProductWorkStep(product: product, workStep: step, sortOrder: 0, unitsRequiredPerProduct: 1, laborRate: 25)

        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        try ctx.save()

        let cost = CostingEngine.stepLaborCost(link: link)
        #expect(cost == Decimal(string: "25")!)

        // Change the rate on the link — cost should update
        link.laborRate = 40
        let updatedCost = CostingEngine.stepLaborCost(link: link)
        #expect(updatedCost == Decimal(string: "40")!)
    }

    @Test("Same step, different rates per product — different costs")
    func sameStepDifferentRatesDifferentCosts() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let productA = Product(title: "Product A")
        let productB = Product(title: "Product B")
        // 3600s, 1 batch unit → 1 hour/unit
        let step = WorkStep(title: "Shared Step", recordedTime: 3600, batchUnitsCompleted: 1)

        let linkA = ProductWorkStep(product: productA, workStep: step, sortOrder: 0, unitsRequiredPerProduct: 1, laborRate: 20)
        let linkB = ProductWorkStep(product: productB, workStep: step, sortOrder: 0, unitsRequiredPerProduct: 1, laborRate: 35)

        productA.productWorkSteps.append(linkA)
        productB.productWorkSteps.append(linkB)
        step.productWorkSteps.append(linkA)
        step.productWorkSteps.append(linkB)

        ctx.insert(productA)
        ctx.insert(productB)
        ctx.insert(step)
        ctx.insert(linkA)
        ctx.insert(linkB)
        try ctx.save()

        // Same step, different rates → different costs
        #expect(CostingEngine.stepLaborCost(link: linkA) == Decimal(string: "20")!)
        #expect(CostingEngine.stepLaborCost(link: linkB) == Decimal(string: "35")!)
    }

    // MARK: - Product Duplication Copies laborRate

    @Test("Product duplication copies laborRate from ProductWorkStep join models")
    func duplicateProductCopiesLaborRate() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let source = Product(title: "Original")
        // 3600s, 1 batch → 1 hr/unit
        let step = WorkStep(title: "Step", recordedTime: 3600, batchUnitsCompleted: 1)
        let link = ProductWorkStep(product: source, workStep: step, sortOrder: 0, unitsRequiredPerProduct: 2, laborRate: Decimal(string: "22.50")!)

        source.productWorkSteps.append(link)
        step.productWorkSteps.append(link)

        ctx.insert(source)
        ctx.insert(step)
        ctx.insert(link)
        try ctx.save()

        // --- Duplicate (mirrors ProductListView.duplicateProduct logic) ---
        let copy = Product(title: "\(source.title) (Copy)")
        ctx.insert(copy)

        for srcLink in source.productWorkSteps {
            guard let ws = srcLink.workStep else { continue }
            let newLink = ProductWorkStep(
                product: copy,
                workStep: ws,
                sortOrder: srcLink.sortOrder,
                unitsRequiredPerProduct: srcLink.unitsRequiredPerProduct,
                laborRate: srcLink.laborRate
            )
            ctx.insert(newLink)
            copy.productWorkSteps.append(newLink)
            ws.productWorkSteps.append(newLink)
        }
        try ctx.save()

        // --- Assertions ---
        let copied = try ctx.fetch(FetchDescriptor<Product>()).first { $0.title == "Original (Copy)" }!
        #expect(copied.productWorkSteps.count == 1)
        #expect(copied.productWorkSteps[0].laborRate == Decimal(string: "22.50")!)
        #expect(copied.productWorkSteps[0].unitsRequiredPerProduct == 2)
        #expect(copied.productWorkSteps[0].workStep?.title == "Step")

        // Shared step — same WorkStep, now linked to 2 products
        let steps = try ctx.fetch(FetchDescriptor<WorkStep>())
        #expect(steps.count == 1)
        #expect(steps[0].productWorkSteps.count == 2)
    }

    // MARK: - Item-Level Metric Isolation

    @Test("unitTimeHours is purely item-level — no product dependency")
    func unitTimeHoursIsItemLevel() {
        // unitTimeHours depends only on step data, not on any product or join model
        let result = CostingEngine.unitTimeHours(recordedTime: 7200, batchUnitsCompleted: 4)
        // 7200s / 4 units / 3600 = 0.5 hours/unit
        #expect(result == Decimal(string: "0.5")!)
    }

    @Test("materialUnitCost is purely item-level — no product dependency")
    func materialUnitCostIsItemLevel() {
        // materialUnitCost depends only on material data, not on any product or join model
        let result = CostingEngine.materialUnitCost(bulkCost: Decimal(string: "30")!, bulkQuantity: Decimal(string: "6")!)
        // $30 / 6 = $5/unit
        #expect(result == Decimal(string: "5")!)
    }
}
