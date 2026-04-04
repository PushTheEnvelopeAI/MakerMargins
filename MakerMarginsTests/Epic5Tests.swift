// Epic5Tests.swift
// MakerMarginsTests
//
// E2E regression tests for Epic 5: Batch Forecasting Calculator.
// Covers batch projection calculations for labor time, material shopping list,
// production cost, and revenue forecasting.
//
// Each test creates its own isolated in-memory ModelContainer so tests
// never share state. Uses Swift Testing (import Testing, @Test, #expect).

import Testing
import Foundation
import SwiftData
@testable import MakerMargins

@MainActor
struct Epic5Tests {

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
            ProductPricing.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Creates a product with 2 work steps and 2 materials for batch testing.
    ///
    /// Step A: 3600s (1h), batch=1, 1 unit/product, $20/hr
    ///   → unitTimeHours = 1.00, laborHoursPerProduct = 1.00, stepLaborCost = $20.00
    /// Step B: 1800s (30m), batch=2, 1 unit/product, $15/hr
    ///   → unitTimeHours = 0.25, laborHoursPerProduct = 0.25, stepLaborCost = $3.75
    ///
    /// Material X: $10 bulk / 5 units, 2 units/product → $2/unit × 2 = $4/product
    /// Material Y: $24 bulk / 8 units, 3 units/product → $3/unit × 3 = $9/product
    ///
    /// Shipping: $5, laborBuffer: 0.05, materialBuffer: 0.10
    ///
    /// Per-unit totals:
    ///   totalLaborHours = 1.25
    ///   totalLaborCost = $23.75 → buffered = $24.9375
    ///   totalMaterialCost = $13 → buffered = $14.30
    ///   totalProductionCost = $24.9375 + $14.30 + $5 = $44.2375
    private func makeTestProduct(ctx: ModelContext) throws -> Product {
        let product = Product(
            title: "Batch Test Product",
            shippingCost: 5,
            materialBuffer: Decimal(string: "0.10")!,
            laborBuffer: Decimal(string: "0.05")!
        )

        let stepA = WorkStep(title: "Step A", recordedTime: 3600, batchUnitsCompleted: 1)
        let linkA = ProductWorkStep(
            product: product, workStep: stepA, sortOrder: 0,
            unitsRequiredPerProduct: 1, laborRate: 20
        )
        product.productWorkSteps.append(linkA)
        stepA.productWorkSteps.append(linkA)

        let stepB = WorkStep(title: "Step B", recordedTime: 1800, batchUnitsCompleted: 2)
        let linkB = ProductWorkStep(
            product: product, workStep: stepB, sortOrder: 1,
            unitsRequiredPerProduct: 1, laborRate: 15
        )
        product.productWorkSteps.append(linkB)
        stepB.productWorkSteps.append(linkB)

        let matX = Material(title: "Material X", bulkCost: 10, bulkQuantity: 5)
        let matLinkX = ProductMaterial(
            product: product, material: matX, sortOrder: 0,
            unitsRequiredPerProduct: 2
        )
        product.productMaterials.append(matLinkX)
        matX.productMaterials.append(matLinkX)

        let matY = Material(title: "Material Y", bulkCost: 24, bulkQuantity: 8)
        let matLinkY = ProductMaterial(
            product: product, material: matY, sortOrder: 1,
            unitsRequiredPerProduct: 3
        )
        product.productMaterials.append(matLinkY)
        matY.productMaterials.append(matLinkY)

        ctx.insert(product)
        ctx.insert(stepA)
        ctx.insert(stepB)
        ctx.insert(linkA)
        ctx.insert(linkB)
        ctx.insert(matX)
        ctx.insert(matY)
        ctx.insert(matLinkX)
        ctx.insert(matLinkY)
        try ctx.save()

        return product
    }

    // MARK: - Batch Labor

    @Test("batchStepHours raw-value multiplies by batch size")
    func batchStepHoursMultiplies() {
        // 0.50 hrs/product × 5 = 2.50
        let result = CostingEngine.batchStepHours(
            laborHoursPerProduct: Decimal(string: "0.50")!,
            batchSize: 5
        )
        #expect(result == Decimal(string: "2.50")!)
    }

    @Test("batchLaborHours sums all steps and multiplies by batch size")
    func batchLaborHoursMultipleSteps() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let product = try makeTestProduct(ctx: ctx)

        // totalLaborHours = 1.25 per unit
        let perUnit = CostingEngine.totalLaborHours(product: product)
        #expect(perUnit == Decimal(string: "1.25")!)

        // batch of 3 → 3.75
        let batch = CostingEngine.batchLaborHours(product: product, batchSize: 3)
        #expect(batch == perUnit * 3)
        #expect(batch == Decimal(string: "3.75")!)
    }

    @Test("batchLaborHours raw-value overload matches model overload")
    func batchLaborHoursRawMatchesModel() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let product = try makeTestProduct(ctx: ctx)

        let perUnit = CostingEngine.totalLaborHours(product: product)
        let modelResult = CostingEngine.batchLaborHours(product: product, batchSize: 7)
        let rawResult = CostingEngine.batchLaborHours(totalLaborHoursPerUnit: perUnit, batchSize: 7)
        #expect(modelResult == rawResult)
    }

    @Test("batchLaborHours returns zero when step has zero recorded time")
    func batchLaborHoursZeroTime() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Zero Time")
        let step = WorkStep(title: "Unrecorded", recordedTime: 0, batchUnitsCompleted: 1)
        let link = ProductWorkStep(
            product: product, workStep: step, sortOrder: 0,
            unitsRequiredPerProduct: 1, laborRate: 25
        )
        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)
        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        try ctx.save()

        let result = CostingEngine.batchLaborHours(product: product, batchSize: 10)
        #expect(result == 0)
    }

    @Test("formatHoursReadable formats various hour values correctly")
    func formatHoursReadableVariousInputs() {
        #expect(CostingEngine.formatHoursReadable(0) == "0h 0m")
        #expect(CostingEngine.formatHoursReadable(Decimal(string: "0.5")!) == "0h 30m")
        #expect(CostingEngine.formatHoursReadable(Decimal(string: "4.75")!) == "4h 45m")
        #expect(CostingEngine.formatHoursReadable(Decimal(string: "25.5")!) == "25h 30m")
    }

    // MARK: - Batch Materials

    @Test("batchMaterialUnits multiplies units per product by batch size")
    func batchMaterialUnitsMultiplies() {
        // 2 units/product × 10 = 20
        let result = CostingEngine.batchMaterialUnits(
            unitsRequiredPerProduct: 2,
            batchSize: 10
        )
        #expect(result == 20)
    }

    @Test("batchMaterialLineCost multiplies line cost by batch size")
    func batchMaterialLineCostMultiplies() {
        // $4/product × 10 = $40
        let result = CostingEngine.batchMaterialLineCost(
            materialLineCostPerUnit: 4,
            batchSize: 10
        )
        #expect(result == 40)
    }

    @Test("bulkPurchasesNeeded exact fit — zero leftover")
    func bulkPurchasesExactFit() {
        // 32 needed, 32 per bulk → 1 purchase, 0 leftover
        let result = CostingEngine.bulkPurchasesNeeded(unitsNeeded: 32, bulkQuantity: 32)
        #expect(result.purchases == 1)
        #expect(result.totalBulkUnits == 32)
        #expect(result.leftover == 0)
    }

    @Test("bulkPurchasesNeeded partial bulk — has leftover")
    func bulkPurchasesPartialBulk() {
        // 30 needed, 32 per bulk → 1 purchase, 2 leftover
        let result = CostingEngine.bulkPurchasesNeeded(unitsNeeded: 30, bulkQuantity: 32)
        #expect(result.purchases == 1)
        #expect(result.totalBulkUnits == 32)
        #expect(result.leftover == 2)
    }

    @Test("bulkPurchasesNeeded multiple bulks required")
    func bulkPurchasesMultipleBulks() {
        // 65 needed, 32 per bulk → 3 purchases (96 total), 31 leftover
        let result = CostingEngine.bulkPurchasesNeeded(unitsNeeded: 65, bulkQuantity: 32)
        #expect(result.purchases == 3)
        #expect(result.totalBulkUnits == 96)
        #expect(result.leftover == 31)
    }

    @Test("bulkPurchasesNeeded zero bulk quantity returns zero guard")
    func bulkPurchasesZeroBulkQuantity() {
        let result = CostingEngine.bulkPurchasesNeeded(unitsNeeded: 10, bulkQuantity: 0)
        #expect(result.purchases == 0)
        #expect(result.totalBulkUnits == 0)
        #expect(result.leftover == 0)
    }

    @Test("batchPurchaseCost multiplies purchases by bulk cost")
    func batchPurchaseCostMultiplies() {
        // 3 purchases × $12 = $36
        let result = CostingEngine.batchPurchaseCost(purchases: 3, bulkCost: 12)
        #expect(result == 36)
    }

    // MARK: - Batch Cost Summary

    @Test("batchProductionCost multiplies per-unit cost by batch size")
    func batchProductionCostMultiplies() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let product = try makeTestProduct(ctx: ctx)

        let perUnit = CostingEngine.totalProductionCost(product: product)
        // $24.9375 + $14.30 + $5 = $44.2375
        #expect(perUnit == Decimal(string: "44.2375")!)

        let batch = CostingEngine.batchProductionCost(product: product, batchSize: 5)
        #expect(batch == perUnit * 5)
        #expect(batch == Decimal(string: "221.1875")!)
    }

    @Test("batchCostPerUnit equals single-unit production cost")
    func batchCostPerUnitEqualsPerUnit() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let product = try makeTestProduct(ctx: ctx)

        let perUnit = CostingEngine.totalProductionCost(product: product)
        let batchCost = CostingEngine.batchProductionCost(product: product, batchSize: 8)
        let costPerUnit = CostingEngine.batchCostPerUnit(batchProductionCost: batchCost, batchSize: 8)
        #expect(costPerUnit == perUnit)
    }

    @Test("batchProductionCost batch of 1 equals single-unit production cost")
    func batchProductionCostBatchOfOne() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let product = try makeTestProduct(ctx: ctx)

        let perUnit = CostingEngine.totalProductionCost(product: product)
        let batch = CostingEngine.batchProductionCost(product: product, batchSize: 1)
        #expect(batch == perUnit)
    }

    // MARK: - Batch Revenue

    @Test("batchRevenue multiplies gross revenue by batch size")
    func batchRevenueMultiplies() {
        // ($25 + $5) × 10 = $300
        let result = CostingEngine.batchRevenue(
            actualPrice: 25,
            actualShippingCharge: 5,
            batchSize: 10
        )
        #expect(result == 300)
    }

    @Test("batchTotalFees includes fixed fee per transaction scaled by batch")
    func batchTotalFeesIncludesFixedFee() {
        // Etsy: $40 item + $10 shipping
        // Single sale fees:
        //   Platform: $50 × 6.5% = $3.25
        //   Processing: $50 × 3% + $0.25 = $1.75
        //   Marketing: $40 × (15% × 20%) = $1.20
        //   Total per sale = $6.20
        // Batch of 5 = $31.00
        let perSale = CostingEngine.totalSaleFees(
            actualPrice: 40,
            actualShippingCharge: 10,
            platformFee: Decimal(string: "0.065")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            paymentProcessingFixed: Decimal(string: "0.25")!,
            marketingFee: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!
        )

        let batch = CostingEngine.batchTotalFees(
            actualPrice: 40,
            actualShippingCharge: 10,
            platformFee: Decimal(string: "0.065")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            paymentProcessingFixed: Decimal(string: "0.25")!,
            marketingFee: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            batchSize: 5
        )

        #expect(batch == perSale * 5)
        // Verify the fixed fee scaled: 5 × $0.25 = $1.25 included
        #expect(batch == Decimal(string: "31.00")!)
    }

    @Test("batchProfit multiplies per-sale profit by batch size")
    func batchProfitMultiplies() {
        // Price $50, shipping charge $10, production cost $25, shipping $8
        // Fees: 5% platform + 2% processing on $60 = $4.20
        // Per-sale profit = $60 - $4.20 - $25 - $8 = $22.80
        // Batch of 10 = $228.00
        let perSale = CostingEngine.actualProfit(
            actualPrice: 50,
            actualShippingCharge: 10,
            productionCostExShipping: 25,
            shippingCost: 8,
            platformFee: Decimal(string: "0.05")!,
            paymentProcessingFee: Decimal(string: "0.02")!,
            paymentProcessingFixed: 0,
            marketingFee: 0,
            percentSalesFromMarketing: 0
        )
        #expect(perSale == Decimal(string: "22.80")!)

        let batch = CostingEngine.batchProfit(
            actualPrice: 50,
            actualShippingCharge: 10,
            productionCostExShipping: 25,
            shippingCost: 8,
            platformFee: Decimal(string: "0.05")!,
            paymentProcessingFee: Decimal(string: "0.02")!,
            paymentProcessingFixed: 0,
            marketingFee: 0,
            percentSalesFromMarketing: 0,
            batchSize: 10
        )

        #expect(batch == perSale * 10)
        #expect(batch == Decimal(string: "228.00")!)
    }

    @Test("batchProfit negative profit scales correctly")
    func batchProfitNegativeScales() {
        // Price $10, shipping $0, production cost $25, shipping cost $5
        // Fees: 5% on $10 = $0.50
        // Per-sale profit = $10 - $0.50 - $25 - $5 = -$20.50
        // Batch of 4 = -$82.00
        let batch = CostingEngine.batchProfit(
            actualPrice: 10,
            actualShippingCharge: 0,
            productionCostExShipping: 25,
            shippingCost: 5,
            platformFee: Decimal(string: "0.05")!,
            paymentProcessingFee: 0,
            paymentProcessingFixed: 0,
            marketingFee: 0,
            percentSalesFromMarketing: 0,
            batchSize: 4
        )

        #expect(batch < 0)
        #expect(batch == Decimal(string: "-82.00")!)
    }

    // MARK: - Integration

    @Test("Full batch forecast with known product — all outputs internally consistent")
    func fullBatchForecastKnownProduct() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let product = try makeTestProduct(ctx: ctx)
        let batchSize = 10

        // Labor hours: 1.25/unit × 10 = 12.50
        let batchHours = CostingEngine.batchLaborHours(product: product, batchSize: batchSize)
        #expect(batchHours == Decimal(string: "12.50")!)

        // Production cost: $44.2375/unit × 10 = $442.375
        let batchCost = CostingEngine.batchProductionCost(product: product, batchSize: batchSize)
        #expect(batchCost == Decimal(string: "442.375")!)

        // Cost per unit equals single-unit cost
        let costPerUnit = CostingEngine.batchCostPerUnit(batchProductionCost: batchCost, batchSize: batchSize)
        #expect(costPerUnit == CostingEngine.totalProductionCost(product: product))

        // Material X: 2 units/product × 10 = 20 needed, bulk=5 → 4 purchases, 0 leftover
        let matXLink = product.productMaterials.sorted { $0.sortOrder < $1.sortOrder }[0]
        let matXUnits = CostingEngine.batchMaterialUnits(link: matXLink, batchSize: batchSize)
        #expect(matXUnits == 20)
        let matXPurchase = CostingEngine.bulkPurchasesNeeded(unitsNeeded: matXUnits, bulkQuantity: 5)
        #expect(matXPurchase.purchases == 4)
        #expect(matXPurchase.leftover == 0)

        // Material Y: 3 units/product × 10 = 30 needed, bulk=8 → 4 purchases (32 total), 2 leftover
        let matYLink = product.productMaterials.sorted { $0.sortOrder < $1.sortOrder }[1]
        let matYUnits = CostingEngine.batchMaterialUnits(link: matYLink, batchSize: batchSize)
        #expect(matYUnits == 30)
        let matYPurchase = CostingEngine.bulkPurchasesNeeded(unitsNeeded: matYUnits, bulkQuantity: 8)
        #expect(matYPurchase.purchases == 4)
        #expect(matYPurchase.totalBulkUnits == 32)
        #expect(matYPurchase.leftover == 2)

        // Revenue with Etsy pricing: $60 actual + $10 shipping, batch of 10
        let pricing = ProductPricing(
            product: product,
            platformType: .etsy,
            platformFee: Decimal(string: "0.065")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            marketingFee: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            profitMargin: Decimal(string: "0.30")!,
            actualPrice: 60,
            actualShippingCharge: 10
        )
        ctx.insert(pricing)
        product.productPricings.append(pricing)
        try ctx.save()

        let revenue = CostingEngine.batchRevenue(
            actualPrice: 60, actualShippingCharge: 10, batchSize: batchSize
        )
        #expect(revenue == 700) // $70 × 10

        let fees = CostingEngine.batchTotalFees(
            actualPrice: 60,
            actualShippingCharge: 10,
            platformFee: Decimal(string: "0.065")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            paymentProcessingFixed: Decimal(string: "0.25")!,
            marketingFee: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            batchSize: batchSize
        )

        let prodCostExShipping = CostingEngine.productionCostExShipping(product: product) * Decimal(batchSize)
        let shippingTotal = product.shippingCost * Decimal(batchSize)
        let profit = revenue - fees - prodCostExShipping - shippingTotal
        let batchProfitResult = CostingEngine.batchProfit(
            actualPrice: 60,
            actualShippingCharge: 10,
            productionCostExShipping: CostingEngine.productionCostExShipping(product: product),
            shippingCost: product.shippingCost,
            platformFee: Decimal(string: "0.065")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            paymentProcessingFixed: Decimal(string: "0.25")!,
            marketingFee: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            batchSize: batchSize
        )
        #expect(batchProfitResult == profit)
    }

    @Test("Empty product with no steps or materials — all batch values are zero")
    func batchForecastEmptyProduct() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Empty", shippingCost: 0, materialBuffer: 0, laborBuffer: 0)
        ctx.insert(product)
        try ctx.save()

        #expect(CostingEngine.batchLaborHours(product: product, batchSize: 10) == 0)
        #expect(CostingEngine.batchProductionCost(product: product, batchSize: 10) == 0)
        #expect(CostingEngine.totalLaborHours(product: product) == 0)
        #expect(CostingEngine.totalMaterialCost(product: product) == 0)
    }

    @Test("Product with costs but no pricing — batch revenue is zero")
    func batchForecastNoPricing() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let product = try makeTestProduct(ctx: ctx)

        // No ProductPricing exists, so actualPrice = 0
        let revenue = CostingEngine.batchRevenue(
            actualPrice: 0,
            actualShippingCharge: 0,
            batchSize: 10
        )
        #expect(revenue == 0)

        // Profit is negative (eats production cost)
        let profit = CostingEngine.batchProfit(
            actualPrice: 0,
            actualShippingCharge: 0,
            productionCostExShipping: CostingEngine.productionCostExShipping(product: product),
            shippingCost: product.shippingCost,
            platformFee: 0,
            paymentProcessingFee: 0,
            paymentProcessingFixed: 0,
            marketingFee: 0,
            percentSalesFromMarketing: 0,
            batchSize: 10
        )
        #expect(profit < 0)
        // Should equal negative of total production cost × 10
        let expectedLoss = -(CostingEngine.productionCostExShipping(product: product) + product.shippingCost) * 10
        #expect(profit == expectedLoss)
    }
}
