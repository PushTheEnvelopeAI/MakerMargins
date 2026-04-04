// Epic6Tests.swift
// MakerMarginsTests
//
// E2E regression tests for Epic 6: Portfolio Metrics & Product Comparison.
// Covers portfolio pricing lookup, product snapshots, portfolio averages,
// and cross-verification against existing CostingEngine functions.
//
// Each test creates its own isolated in-memory ModelContainer so tests
// never share state. Uses Swift Testing (import Testing, @Test, #expect).

import Testing
import Foundation
import SwiftData
@testable import MakerMargins

@MainActor
struct Epic6Tests {

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

    /// Creates a product with 2 work steps and 2 materials — identical to Epic5Tests
    /// helper for known, pre-verified values.
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
    ///   totalLaborHours      = 1.25
    ///   totalLaborCost       = $23.75 → buffered = $24.9375
    ///   totalMaterialCost    = $13.00 → buffered = $14.30
    ///   totalProductionCost  = $24.9375 + $14.30 + $5 = $44.2375
    ///   productionCostExShip = $39.2375
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

    /// Creates a simple product with 1 step and 1 material for multi-product tests.
    ///
    /// With defaults (batchUnitsCompleted=1, unitsRequiredPerProduct=1, bulkQuantity=1):
    ///   totalLaborHours = recordedTime / 3600
    ///   totalLaborCost  = hours × laborRate → buffered = × (1 + laborBuffer)
    ///   totalMaterialCost = bulkCost → buffered = × (1 + materialBuffer)
    ///   totalProductionCost = laborBuffered + materialBuffered + shippingCost
    @discardableResult
    private func makeSimpleProduct(
        ctx: ModelContext,
        title: String,
        laborRate: Decimal,
        recordedTime: TimeInterval,
        bulkCost: Decimal,
        shippingCost: Decimal = 0,
        laborBuffer: Decimal = 0,
        materialBuffer: Decimal = 0
    ) throws -> Product {
        let product = Product(
            title: title,
            shippingCost: shippingCost,
            materialBuffer: materialBuffer,
            laborBuffer: laborBuffer
        )

        let step = WorkStep(title: "\(title) Step", recordedTime: recordedTime, batchUnitsCompleted: 1)
        let link = ProductWorkStep(
            product: product, workStep: step, sortOrder: 0,
            unitsRequiredPerProduct: 1, laborRate: laborRate
        )
        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)

        let material = Material(title: "\(title) Material", bulkCost: bulkCost, bulkQuantity: 1)
        let matLink = ProductMaterial(
            product: product, material: material, sortOrder: 0,
            unitsRequiredPerProduct: 1
        )
        product.productMaterials.append(matLink)
        material.productMaterials.append(matLink)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        ctx.insert(material)
        ctx.insert(matLink)
        try ctx.save()

        return product
    }

    /// Attaches a General ProductPricing with simple fees (5% platform + 3% processing).
    /// No marketing, no fixed fees — keeps hand-computation simple.
    ///
    /// totalSaleFees = grossRevenue × 0.08
    /// actualProfit = grossRevenue × 0.92 - productionCost
    @discardableResult
    private func addGeneralPricing(
        to product: Product,
        ctx: ModelContext,
        actualPrice: Decimal,
        actualShippingCharge: Decimal = 0
    ) throws -> ProductPricing {
        let pricing = ProductPricing(
            product: product,
            platformType: .general,
            platformFee: Decimal(string: "0.05")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            marketingFee: 0,
            percentSalesFromMarketing: 0,
            profitMargin: Decimal(string: "0.30")!,
            actualPrice: actualPrice,
            actualShippingCharge: actualShippingCharge
        )
        ctx.insert(pricing)
        product.productPricings.append(pricing)
        try ctx.save()
        return pricing
    }

    // MARK: - portfolioPricing

    @Test("portfolioPricing returns nil when product has no pricing records")
    func portfolioPricingNoRecords() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "No Pricing")
        ctx.insert(product)
        try ctx.save()

        #expect(CostingEngine.portfolioPricing(for: product, platform: .general) == nil)
        #expect(CostingEngine.portfolioPricing(for: product, platform: .etsy) == nil)
    }

    @Test("portfolioPricing returns General pricing when it has actualPrice > 0")
    func portfolioPricingGeneralWithPrice() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Has General")
        ctx.insert(product)
        try addGeneralPricing(to: product, ctx: ctx, actualPrice: 80)

        let result = CostingEngine.portfolioPricing(for: product, platform: .general)
        #expect(result != nil)
        #expect(result?.platformType == .general)
        #expect(result?.actualPrice == 80)
    }

    @Test("portfolioPricing returns nil for Etsy when only General pricing exists")
    func portfolioPricingGeneralExistsQueryEtsy() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "General Only")
        ctx.insert(product)
        try addGeneralPricing(to: product, ctx: ctx, actualPrice: 80)

        #expect(CostingEngine.portfolioPricing(for: product, platform: .etsy) == nil)
    }

    @Test("portfolioPricing returns Etsy pricing when queried for Etsy")
    func portfolioPricingEtsyWithPrice() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Has Etsy")
        ctx.insert(product)

        let pricing = ProductPricing(
            product: product,
            platformType: .etsy,
            platformFee: Decimal(string: "0.065")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            marketingFee: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            profitMargin: Decimal(string: "0.30")!,
            actualPrice: 60,
            actualShippingCharge: 8
        )
        ctx.insert(pricing)
        product.productPricings.append(pricing)
        try ctx.save()

        let result = CostingEngine.portfolioPricing(for: product, platform: .etsy)
        #expect(result != nil)
        #expect(result?.platformType == .etsy)
        #expect(result?.actualPrice == 60)
    }

    @Test("portfolioPricing returns nil when General pricing has actualPrice = 0")
    func portfolioPricingZeroPrice() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Zero Price")
        ctx.insert(product)

        let pricing = ProductPricing(
            product: product,
            platformType: .general,
            actualPrice: 0
        )
        ctx.insert(pricing)
        product.productPricings.append(pricing)
        try ctx.save()

        #expect(CostingEngine.portfolioPricing(for: product, platform: .general) == nil)
    }

    // MARK: - productSnapshot

    @Test("productSnapshot full product — all fields populated with correct values")
    func productSnapshotFullProduct() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let product = try makeTestProduct(ctx: ctx)
        try addGeneralPricing(to: product, ctx: ctx, actualPrice: 80, actualShippingCharge: 10)

        let snap = CostingEngine.productSnapshot(product: product, platform: .general)

        #expect(snap.hasPricing == true)
        #expect(snap.platformLabel == "General")
        #expect(snap.productionCost == Decimal(string: "44.2375")!)
        #expect(snap.laborCostBuffered == Decimal(string: "24.9375")!)
        #expect(snap.materialCostBuffered == Decimal(string: "14.30")!)
        #expect(snap.shippingCost == 5)
        #expect(snap.totalLaborHours == Decimal(string: "1.25")!)

        // grossRevenue = $90, fees = $90 × 0.08 = $7.20
        // profit = $90 - $7.20 - $39.2375 - $5 = $38.5625
        #expect(snap.profit == Decimal(string: "38.5625")!)

        // earnings = profit + laborCostBuffered = $38.5625 + $24.9375 = $63.50
        #expect(snap.earnings == Decimal(string: "63.50")!)

        #expect(snap.profitMargin != nil)
        #expect(snap.hourlyRate != nil)
    }

    @Test("productSnapshot no pricing — hasPricing false, profit fields zero/nil, costs populated")
    func productSnapshotNoPricing() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let product = try makeTestProduct(ctx: ctx)

        let snap = CostingEngine.productSnapshot(product: product, platform: .general)

        #expect(snap.hasPricing == false)
        #expect(snap.earnings == 0)
        #expect(snap.profit == 0)
        #expect(snap.profitMargin == nil)
        #expect(snap.hourlyRate == nil)
        // Cost fields still populated
        #expect(snap.productionCost == Decimal(string: "44.2375")!)
        #expect(snap.laborCostBuffered == Decimal(string: "24.9375")!)
        #expect(snap.totalLaborHours == Decimal(string: "1.25")!)
    }

    @Test("productSnapshot no labor steps — hourlyRate nil, laborCostBuffered zero")
    func productSnapshotNoLaborSteps() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Product with only 1 material, no steps
        let product = Product(title: "Materials Only", shippingCost: 3)
        let material = Material(title: "Fabric", bulkCost: 20, bulkQuantity: 1)
        let matLink = ProductMaterial(
            product: product, material: material, sortOrder: 0,
            unitsRequiredPerProduct: 1
        )
        product.productMaterials.append(matLink)
        material.productMaterials.append(matLink)

        ctx.insert(product)
        ctx.insert(material)
        ctx.insert(matLink)
        try ctx.save()

        try addGeneralPricing(to: product, ctx: ctx, actualPrice: 50)

        let snap = CostingEngine.productSnapshot(product: product, platform: .general)

        #expect(snap.hasPricing == true)
        #expect(snap.hourlyRate == nil)
        #expect(snap.laborCostBuffered == 0)
        #expect(snap.totalLaborHours == 0)
        #expect(snap.materialCostBuffered == 20)
        // earnings = profit + 0 labor = profit
        #expect(snap.earnings == snap.profit)
    }

    @Test("productSnapshot no materials — materialCostBuffered zero, other fields normal")
    func productSnapshotNoMaterials() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Product with only 1 step, no materials
        let product = Product(title: "Labor Only", shippingCost: 5)
        let step = WorkStep(title: "Work", recordedTime: 3600, batchUnitsCompleted: 1)
        let link = ProductWorkStep(
            product: product, workStep: step, sortOrder: 0,
            unitsRequiredPerProduct: 1, laborRate: 20
        )
        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        try ctx.save()

        try addGeneralPricing(to: product, ctx: ctx, actualPrice: 50)

        let snap = CostingEngine.productSnapshot(product: product, platform: .general)

        #expect(snap.hasPricing == true)
        #expect(snap.materialCostBuffered == 0)
        #expect(snap.laborCostBuffered == 20) // 1hr × $20, no buffer
        #expect(snap.totalLaborHours == 1)
        #expect(snap.hourlyRate != nil)
        #expect(snap.profitMargin != nil)
    }

    @Test("productSnapshot empty product — all fields zero or nil")
    func productSnapshotEmptyProduct() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Empty")
        ctx.insert(product)
        try ctx.save()

        let snap = CostingEngine.productSnapshot(product: product, platform: .general)

        #expect(snap.hasPricing == false)
        #expect(snap.productionCost == 0)
        #expect(snap.laborCostBuffered == 0)
        #expect(snap.materialCostBuffered == 0)
        #expect(snap.shippingCost == 0)
        #expect(snap.totalLaborHours == 0)
        #expect(snap.earnings == 0)
        #expect(snap.profit == 0)
        #expect(snap.profitMargin == nil)
        #expect(snap.hourlyRate == nil)
    }

    // MARK: - portfolioAverages

    @Test("portfolioAverages mixed — averages only from priced products")
    func portfolioAveragesMixed() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Product A: priced, $30 labor + $10 material = $40 cost, price $80
        let pA = try makeSimpleProduct(ctx: ctx, title: "A", laborRate: 30, recordedTime: 3600, bulkCost: 10)
        try addGeneralPricing(to: pA, ctx: ctx, actualPrice: 80)

        // Product B: priced, $15 labor + $5 material = $20 cost, price $40
        let pB = try makeSimpleProduct(ctx: ctx, title: "B", laborRate: 15, recordedTime: 3600, bulkCost: 5)
        try addGeneralPricing(to: pB, ctx: ctx, actualPrice: 40)

        // Product C: NOT priced
        try makeSimpleProduct(ctx: ctx, title: "C", laborRate: 10, recordedTime: 3600, bulkCost: 8)

        let products = try ctx.fetch(FetchDescriptor<Product>())
        let snapshots = CostingEngine.portfolioSnapshots(products: products, platform: .general)
        let avg = CostingEngine.portfolioAverages(snapshots: snapshots)

        #expect(avg.pricedCount == 2)
        #expect(avg.totalCount == 3)
        // Averages computed from only 2 priced products
        let snapA = snapshots.first(where: { $0.product.title == "A" })!
        let snapB = snapshots.first(where: { $0.product.title == "B" })!
        let expectedAvgEarnings = (snapA.earnings + snapB.earnings) / 2
        #expect(avg.avgEarnings == expectedAvgEarnings)
    }

    @Test("portfolioAverages all priced — pricedCount equals totalCount")
    func portfolioAveragesAllPriced() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let pA = try makeSimpleProduct(ctx: ctx, title: "A", laborRate: 20, recordedTime: 3600, bulkCost: 10)
        try addGeneralPricing(to: pA, ctx: ctx, actualPrice: 60)

        let pB = try makeSimpleProduct(ctx: ctx, title: "B", laborRate: 15, recordedTime: 1800, bulkCost: 8)
        try addGeneralPricing(to: pB, ctx: ctx, actualPrice: 40)

        let products = try ctx.fetch(FetchDescriptor<Product>())
        let snapshots = CostingEngine.portfolioSnapshots(products: products, platform: .general)
        let avg = CostingEngine.portfolioAverages(snapshots: snapshots)

        #expect(avg.pricedCount == 2)
        #expect(avg.totalCount == 2)
        #expect(avg.avgProfitMargin != nil)
        #expect(avg.avgHourlyRate != nil)
    }

    @Test("portfolioAverages none priced — safe defaults")
    func portfolioAveragesNonePriced() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        try makeSimpleProduct(ctx: ctx, title: "A", laborRate: 20, recordedTime: 3600, bulkCost: 10)
        try makeSimpleProduct(ctx: ctx, title: "B", laborRate: 15, recordedTime: 1800, bulkCost: 8)

        let products = try ctx.fetch(FetchDescriptor<Product>())
        let snapshots = CostingEngine.portfolioSnapshots(products: products, platform: .general)
        let avg = CostingEngine.portfolioAverages(snapshots: snapshots)

        #expect(avg.pricedCount == 0)
        #expect(avg.totalCount == 2)
        #expect(avg.avgEarnings == 0)
        #expect(avg.avgProfitMargin == nil)
        #expect(avg.avgHourlyRate == nil)
    }

    @Test("portfolioAverages single product — averages equal own values")
    func portfolioAveragesSingleProduct() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = try makeTestProduct(ctx: ctx)
        try addGeneralPricing(to: product, ctx: ctx, actualPrice: 80, actualShippingCharge: 10)

        let snapshots = CostingEngine.portfolioSnapshots(products: [product], platform: .general)
        let avg = CostingEngine.portfolioAverages(snapshots: snapshots)
        let snap = snapshots[0]

        #expect(avg.pricedCount == 1)
        #expect(avg.totalCount == 1)
        #expect(avg.avgEarnings == snap.earnings)
        #expect(avg.avgProfitMargin == snap.profitMargin)
        #expect(avg.avgHourlyRate == snap.hourlyRate)
    }

    @Test("portfolioAverages includes negative profit — not filtered out")
    func portfolioAveragesNegativeProfitIncluded() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Product A: profitable — $10 labor + $5 material = $15 cost, price $60
        let pA = try makeSimpleProduct(ctx: ctx, title: "Profitable", laborRate: 10, recordedTime: 3600, bulkCost: 5)
        try addGeneralPricing(to: pA, ctx: ctx, actualPrice: 60)

        // Product B: unprofitable — $50 labor + $30 material = $80 cost, price $20
        let pB = try makeSimpleProduct(ctx: ctx, title: "Losing Money", laborRate: 50, recordedTime: 3600, bulkCost: 30)
        try addGeneralPricing(to: pB, ctx: ctx, actualPrice: 20)

        let products = try ctx.fetch(FetchDescriptor<Product>())
        let snapshots = CostingEngine.portfolioSnapshots(products: products, platform: .general)
        let avg = CostingEngine.portfolioAverages(snapshots: snapshots)

        #expect(avg.pricedCount == 2)
        // The losing product should drag the average down
        let snapB = snapshots.first(where: { $0.product.title == "Losing Money" })!
        #expect(snapB.profit < 0)
        let snapA = snapshots.first(where: { $0.product.title == "Profitable" })!
        #expect(avg.avgEarnings == (snapA.earnings + snapB.earnings) / 2)
    }

    // MARK: - Cross-Verification

    @Test("snapshot earnings matches direct CostingEngine calculation")
    func snapshotEarningsMatchesDirect() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let product = try makeTestProduct(ctx: ctx)
        let pricing = try addGeneralPricing(to: product, ctx: ctx, actualPrice: 80, actualShippingCharge: 10)

        let snap = CostingEngine.productSnapshot(product: product, platform: .general)

        // Compute directly using existing CostingEngine functions
        let fees = CostingEngine.resolvedFees(
            platformType: .general,
            userPlatformFee: pricing.platformFee,
            userPaymentProcessingFee: pricing.paymentProcessingFee,
            userMarketingFee: pricing.marketingFee,
            userPercentSalesFromMarketing: pricing.percentSalesFromMarketing,
            userProfitMargin: pricing.profitMargin
        )
        let directProfit = CostingEngine.actualProfit(
            product: product,
            actualPrice: pricing.actualPrice,
            actualShippingCharge: pricing.actualShippingCharge,
            platformFee: fees.platformFee,
            paymentProcessingFee: fees.paymentProcessingFee,
            paymentProcessingFixed: fees.paymentProcessingFixed,
            marketingFee: fees.marketingFee,
            percentSalesFromMarketing: fees.percentSalesFromMarketing
        )
        let directLabor = CostingEngine.totalLaborCostBuffered(product: product)
        let directEarnings = directProfit + directLabor

        #expect(snap.earnings == directEarnings)
        #expect(snap.profit == directProfit)
    }

    @Test("snapshot profitMargin matches direct CostingEngine calculation")
    func snapshotProfitMarginMatchesDirect() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let product = try makeTestProduct(ctx: ctx)
        let pricing = try addGeneralPricing(to: product, ctx: ctx, actualPrice: 80, actualShippingCharge: 10)

        let snap = CostingEngine.productSnapshot(product: product, platform: .general)

        let directMargin = CostingEngine.actualProfitMargin(
            profit: snap.profit,
            actualPrice: pricing.actualPrice,
            actualShippingCharge: pricing.actualShippingCharge
        )

        #expect(snap.profitMargin == directMargin)
    }

    @Test("snapshots sorted by earnings produce correct descending order")
    func snapshotsSortedByEarnings() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // High earner: $50 labor + $10 material, price $200
        let high = try makeSimpleProduct(ctx: ctx, title: "High", laborRate: 50, recordedTime: 3600, bulkCost: 10)
        try addGeneralPricing(to: high, ctx: ctx, actualPrice: 200)

        // Mid earner: $20 labor + $10 material, price $80
        let mid = try makeSimpleProduct(ctx: ctx, title: "Mid", laborRate: 20, recordedTime: 3600, bulkCost: 10)
        try addGeneralPricing(to: mid, ctx: ctx, actualPrice: 80)

        // Low earner: $10 labor + $5 material, price $30
        let low = try makeSimpleProduct(ctx: ctx, title: "Low", laborRate: 10, recordedTime: 3600, bulkCost: 5)
        try addGeneralPricing(to: low, ctx: ctx, actualPrice: 30)

        let products = try ctx.fetch(FetchDescriptor<Product>())
        let snapshots = CostingEngine.portfolioSnapshots(products: products, platform: .general)
        let sorted = snapshots.sorted { $0.earnings > $1.earnings }

        #expect(sorted[0].product.title == "High")
        #expect(sorted[1].product.title == "Mid")
        #expect(sorted[2].product.title == "Low")
        #expect(sorted[0].earnings > sorted[1].earnings)
        #expect(sorted[1].earnings > sorted[2].earnings)
    }

    @Test("snapshots sorted by production cost produce correct descending order")
    func snapshotsSortedByProductionCost() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Expensive: $60 labor + $40 material + $10 shipping = $110
        let expensive = try makeSimpleProduct(
            ctx: ctx, title: "Expensive", laborRate: 60, recordedTime: 3600,
            bulkCost: 40, shippingCost: 10
        )

        // Cheap: $10 labor + $5 material + $0 shipping = $15
        let cheap = try makeSimpleProduct(
            ctx: ctx, title: "Cheap", laborRate: 10, recordedTime: 3600,
            bulkCost: 5
        )

        // Mid: $25 labor + $15 material + $3 shipping = $43
        let mid = try makeSimpleProduct(
            ctx: ctx, title: "Mid", laborRate: 25, recordedTime: 3600,
            bulkCost: 15, shippingCost: 3
        )

        let products = [expensive, cheap, mid]
        let snapshots = CostingEngine.portfolioSnapshots(products: products, platform: .general)
        let sorted = snapshots.sorted { $0.productionCost > $1.productionCost }

        #expect(sorted[0].product.title == "Expensive")
        #expect(sorted[1].product.title == "Mid")
        #expect(sorted[2].product.title == "Cheap")
    }

    @Test("snapshots include all products regardless of category")
    func snapshotsDifferentCategories() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let catA = Category(name: "Woodworking")
        let catB = Category(name: "Candles")
        ctx.insert(catA)
        ctx.insert(catB)

        let p1 = Product(title: "Cutting Board", category: catA)
        let p2 = Product(title: "Soy Candle", category: catB)
        let p3 = Product(title: "Uncategorized Item")
        ctx.insert(p1)
        ctx.insert(p2)
        ctx.insert(p3)
        try ctx.save()

        let snapshots = CostingEngine.portfolioSnapshots(products: [p1, p2, p3], platform: .general)

        #expect(snapshots.count == 3)
        let titles = Set(snapshots.map { $0.product.title })
        #expect(titles.contains("Cutting Board"))
        #expect(titles.contains("Soy Candle"))
        #expect(titles.contains("Uncategorized Item"))
    }
}
