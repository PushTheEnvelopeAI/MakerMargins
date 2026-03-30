// Epic2Tests.swift
// MakerMarginsTests
//
// E2E regression tests for Epic 2: Labor Engine & Stopwatch.
// Covers WorkStep CRUD, ProductWorkStep join model behaviour,
// shared step semantics, cascade deletes, CostingEngine calculations,
// and LaborRateManager persistence.
//
// Each test creates its own isolated in-memory ModelContainer so tests
// never share state. Uses Swift Testing (import Testing, @Test, #expect).

import Testing
import Foundation
import SwiftData
@testable import MakerMargins

@MainActor
struct Epic2Tests {

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

    // MARK: - WorkStep & ProductWorkStep CRUD

    @Test("Create a WorkStep with all fields, persist, and fetch back")
    func createAndFetchWorkStep() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let step = WorkStep(
            title: "Sand edges",
            summary: "220 grit then 400 grit",
            laborRate: Decimal(string: "25.00")!,
            recordedTime: 1800,
            batchUnitsCompleted: Decimal(string: "4")!,
            unitName: "piece",
            defaultUnitsPerProduct: Decimal(string: "2")!
        )
        ctx.insert(step)
        try ctx.save()

        let results = try ctx.fetch(FetchDescriptor<WorkStep>())
        #expect(results.count == 1)
        #expect(results[0].title == "Sand edges")
        #expect(results[0].summary == "220 grit then 400 grit")
        #expect(results[0].laborRate == Decimal(string: "25.00")!)
        #expect(results[0].recordedTime == 1800)
        #expect(results[0].batchUnitsCompleted == Decimal(string: "4")!)
        #expect(results[0].unitName == "piece")
        #expect(results[0].defaultUnitsPerProduct == Decimal(string: "2")!)
    }

    @Test("Create a ProductWorkStep association and verify sortOrder")
    func createProductWorkStepAssociation() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Walnut Bowl")
        let step = WorkStep(title: "Turning")
        let link = ProductWorkStep(product: product, workStep: step, sortOrder: 3)

        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        try ctx.save()

        let products = try ctx.fetch(FetchDescriptor<Product>())
        #expect(products[0].productWorkSteps.count == 1)
        #expect(products[0].productWorkSteps[0].sortOrder == 3)
        #expect(products[0].productWorkSteps[0].workStep?.title == "Turning")
    }

    @Test("Shared step linked to two products reflects edits in both")
    func sharedStepAcrossProducts() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let productA = Product(title: "Product A")
        let productB = Product(title: "Product B")
        let step = WorkStep(title: "Shared Sanding", recordedTime: 600)

        let linkA = ProductWorkStep(product: productA, workStep: step, sortOrder: 0)
        let linkB = ProductWorkStep(product: productB, workStep: step, sortOrder: 0)

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

        #expect(step.productWorkSteps.count == 2)

        // Edit the step — should be visible from both products
        step.recordedTime = 1200
        try ctx.save()

        let stepFromA = productA.productWorkSteps[0].workStep
        let stepFromB = productB.productWorkSteps[0].workStep
        #expect(stepFromA?.recordedTime == 1200)
        #expect(stepFromB?.recordedTime == 1200)
    }

    @Test("Deleting a product removes associations but preserves the shared WorkStep")
    func deleteProductPreservesSharedStep() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Doomed Product")
        let step = WorkStep(title: "Survivor Step")
        let link = ProductWorkStep(product: product, workStep: step, sortOrder: 0)

        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        try ctx.save()

        ctx.delete(product)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<Product>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<ProductWorkStep>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<WorkStep>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<WorkStep>())[0].title == "Survivor Step")
    }

    @Test("Deleting a WorkStep cascades to its ProductWorkStep associations")
    func deleteWorkStepCascadesToAssociations() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Keeper Product")
        let step = WorkStep(title: "Doomed Step")
        let link = ProductWorkStep(product: product, workStep: step, sortOrder: 0)

        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        try ctx.save()

        ctx.delete(step)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<WorkStep>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<ProductWorkStep>()).isEmpty)
        // Product survives
        let products = try ctx.fetch(FetchDescriptor<Product>())
        #expect(products.count == 1)
        #expect(products[0].title == "Keeper Product")
    }

    @Test("Reordering steps updates sortOrder values correctly")
    func reorderStepsUpdatesSortOrder() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Reorder Product")
        let stepA = WorkStep(title: "Step A")
        let stepB = WorkStep(title: "Step B")
        let stepC = WorkStep(title: "Step C")

        let linkA = ProductWorkStep(product: product, workStep: stepA, sortOrder: 0)
        let linkB = ProductWorkStep(product: product, workStep: stepB, sortOrder: 1)
        let linkC = ProductWorkStep(product: product, workStep: stepC, sortOrder: 2)

        product.productWorkSteps.append(linkA)
        product.productWorkSteps.append(linkB)
        product.productWorkSteps.append(linkC)
        stepA.productWorkSteps.append(linkA)
        stepB.productWorkSteps.append(linkB)
        stepC.productWorkSteps.append(linkC)

        ctx.insert(product)
        ctx.insert(stepA)
        ctx.insert(stepB)
        ctx.insert(stepC)
        ctx.insert(linkA)
        ctx.insert(linkB)
        ctx.insert(linkC)
        try ctx.save()

        // Simulate moving Step C (index 2) to position 0 (before Step A)
        // New order: C, A, B
        var links = product.productWorkSteps.sorted { $0.sortOrder < $1.sortOrder }
        links.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        for (index, link) in links.enumerated() {
            link.sortOrder = index
        }
        try ctx.save()

        let sorted = product.productWorkSteps.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted[0].workStep?.title == "Step C")
        #expect(sorted[0].sortOrder == 0)
        #expect(sorted[1].workStep?.title == "Step A")
        #expect(sorted[1].sortOrder == 1)
        #expect(sorted[2].workStep?.title == "Step B")
        #expect(sorted[2].sortOrder == 2)
    }

    // MARK: - CostingEngine Calculations

    @Test("unitTimeHours returns correct value for known inputs")
    func unitTimeHoursKnownValues() {
        // 3600 seconds / 2 batch units = 1800 seconds per unit = 0.5 hours
        let result = CostingEngine.unitTimeHours(recordedTime: 3600, batchUnitsCompleted: 2)
        #expect(result == Decimal(string: "0.5")!)
    }

    @Test("unitTimeHours returns zero when batchUnitsCompleted is zero")
    func unitTimeHoursZeroBatchGuard() {
        let result = CostingEngine.unitTimeHours(recordedTime: 3600, batchUnitsCompleted: 0)
        #expect(result == 0)
    }

    @Test("stepLaborCost returns correct value for known inputs")
    func stepLaborCostKnownValues() {
        // 3600s, 2 batch units → 0.5 hours/unit
        // 1 unit/product, $20/hr → 0.5 * 1 * 20 = $10
        let result = CostingEngine.stepLaborCost(
            recordedTime: 3600,
            batchUnitsCompleted: 2,
            unitsRequiredPerProduct: 1,
            laborRate: 20
        )
        #expect(result == Decimal(string: "10")!)
    }

    @Test("totalLaborCost sums across multiple steps linked to a product")
    func totalLaborCostMultipleSteps() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Multi-step Product")

        // Step A: 3600s, 1 batch unit, 1 unit/product, $20/hr → $20
        let stepA = WorkStep(
            title: "Step A",
            laborRate: 20,
            recordedTime: 3600,
            batchUnitsCompleted: 1,
            defaultUnitsPerProduct: 1
        )
        // Step B: 1800s, 1 batch unit, 2 units/product, $15/hr
        // 0.5 hours/unit × 2 units/product × $15/hr = $15
        let stepB = WorkStep(
            title: "Step B",
            laborRate: 15,
            recordedTime: 1800,
            batchUnitsCompleted: 1,
            defaultUnitsPerProduct: 2
        )

        let linkA = ProductWorkStep(product: product, workStep: stepA, sortOrder: 0)
        let linkB = ProductWorkStep(product: product, workStep: stepB, sortOrder: 1)

        product.productWorkSteps.append(linkA)
        product.productWorkSteps.append(linkB)
        stepA.productWorkSteps.append(linkA)
        stepB.productWorkSteps.append(linkB)

        ctx.insert(product)
        ctx.insert(stepA)
        ctx.insert(stepB)
        ctx.insert(linkA)
        ctx.insert(linkB)
        try ctx.save()

        let total = CostingEngine.totalLaborCost(product: product)
        #expect(total == Decimal(string: "35")!)
    }

    @Test("totalProductionCost applies buffers correctly")
    func totalProductionCostWithBuffers() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Product: shipping $5, materialBuffer 10%, laborBuffer 5%
        let product = Product(
            title: "Buffered Product",
            shippingCost: Decimal(string: "5")!,
            materialBuffer: Decimal(string: "0.10")!,
            laborBuffer: Decimal(string: "0.05")!
        )

        // One step: 3600s, 1 batch, 1 unit/product, $20/hr → $20 labor
        let step = WorkStep(
            title: "Only Step",
            laborRate: 20,
            recordedTime: 3600,
            batchUnitsCompleted: 1,
            defaultUnitsPerProduct: 1
        )

        let link = ProductWorkStep(product: product, workStep: step, sortOrder: 0)
        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        try ctx.save()

        // Per-section buffers: $20 × (1 + 0.05) + $0 × (1 + 0.10) + $5 = $21 + $0 + $5 = $26
        let total = CostingEngine.totalProductionCost(product: product)
        #expect(total == Decimal(string: "26")!)
    }

    // MARK: - LaborRateManager

    @Test("LaborRateManager persists default rate to UserDefaults")
    func laborRateManagerUserDefaultsRoundTrip() {
        let key = "defaultLaborRate"
        // Clean slate
        UserDefaults.standard.removeObject(forKey: key)

        let manager = LaborRateManager()
        // Default should be 15 when no UserDefaults value exists
        #expect(manager.defaultRate == 15)

        // Set a custom rate
        manager.defaultRate = Decimal(string: "22.50")!

        // New instance should read the persisted value
        let manager2 = LaborRateManager()
        #expect(manager2.defaultRate == Decimal(string: "22.50")!)

        // Clean up
        UserDefaults.standard.removeObject(forKey: key)
    }
}
