// Epic4Tests.swift
// MakerMarginsTests
//
// E2E regression tests for Epic 4: Target Price Calculator.
// Covers PlatformFeeProfile CRUD, ProductPricing CRUD, PlatformType
// locked constants and editability flags, CostingEngine target price
// calculations, and product duplication with pricing overrides.
//
// Each test creates its own isolated in-memory ModelContainer so tests
// never share state. Uses Swift Testing (import Testing, @Test, #expect).

import Testing
import Foundation
import SwiftData
@testable import MakerMargins

@MainActor
struct Epic4Tests {

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

    // MARK: - Model CRUD: PlatformFeeProfile

    @Test("Create PlatformFeeProfile with all fields, persist, and fetch back")
    func createAndFetchPlatformFeeProfile() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let profile = PlatformFeeProfile(
            platformType: .etsy,
            transactionFeePercentage: Decimal(string: "0.05")!,
            fixedFeePerSale: Decimal(string: "0.45")!,
            marketingFeeRate: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            profitMargin: Decimal(string: "0.35")!
        )
        ctx.insert(profile)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PlatformFeeProfile>())
        #expect(fetched.count == 1)
        #expect(fetched[0].platformType == .etsy)
        #expect(fetched[0].transactionFeePercentage == Decimal(string: "0.05")!)
        #expect(fetched[0].fixedFeePerSale == Decimal(string: "0.45")!)
        #expect(fetched[0].marketingFeeRate == Decimal(string: "0.15")!)
        #expect(fetched[0].percentSalesFromMarketing == Decimal(string: "0.20")!)
        #expect(fetched[0].profitMargin == Decimal(string: "0.35")!)
    }

    // MARK: - Model CRUD: ProductPricing

    @Test("Create ProductPricing linked to Product, persist, and fetch back")
    func createAndFetchProductPricing() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Test Product")
        let pricing = ProductPricing(
            product: product,
            platformType: .shopify,
            transactionFeePercentage: Decimal(string: "0.03")!,
            fixedFeePerSale: Decimal(string: "0.30")!,
            marketingFeeRate: Decimal(string: "0.10")!,
            percentSalesFromMarketing: Decimal(string: "0.25")!,
            profitMargin: Decimal(string: "0.40")!
        )

        ctx.insert(product)
        ctx.insert(pricing)
        product.productPricings.append(pricing)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<ProductPricing>())
        #expect(fetched.count == 1)
        #expect(fetched[0].platformType == .shopify)
        #expect(fetched[0].transactionFeePercentage == Decimal(string: "0.03")!)
        #expect(fetched[0].fixedFeePerSale == Decimal(string: "0.30")!)
        #expect(fetched[0].marketingFeeRate == Decimal(string: "0.10")!)
        #expect(fetched[0].percentSalesFromMarketing == Decimal(string: "0.25")!)
        #expect(fetched[0].profitMargin == Decimal(string: "0.40")!)
        #expect(fetched[0].product?.title == "Test Product")
    }

    @Test("Deleting Product cascade-deletes ProductPricing, PlatformFeeProfile survives")
    func deleteProductCascadesProductPricing() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Test Product")
        let pricing = ProductPricing(product: product, platformType: .etsy, profitMargin: Decimal(string: "0.30")!)
        let profile = PlatformFeeProfile(platformType: .etsy)

        ctx.insert(product)
        ctx.insert(pricing)
        ctx.insert(profile)
        product.productPricings.append(pricing)
        try ctx.save()

        ctx.delete(product)
        try ctx.save()

        let pricings = try ctx.fetch(FetchDescriptor<ProductPricing>())
        #expect(pricings.isEmpty)

        let profiles = try ctx.fetch(FetchDescriptor<PlatformFeeProfile>())
        #expect(profiles.count == 1)
    }

    @Test("Same product, two platforms — independent profitMargin overrides")
    func perPlatformPricingIndependence() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Test Product")
        let generalPricing = ProductPricing(product: product, platformType: .general, profitMargin: Decimal(string: "0.30")!)
        let etsyPricing = ProductPricing(product: product, platformType: .etsy, profitMargin: Decimal(string: "0.25")!)

        ctx.insert(product)
        ctx.insert(generalPricing)
        ctx.insert(etsyPricing)
        product.productPricings.append(generalPricing)
        product.productPricings.append(etsyPricing)
        try ctx.save()

        // Change General margin — Etsy should be unaffected
        generalPricing.profitMargin = Decimal(string: "0.40")!
        try ctx.save()

        #expect(generalPricing.profitMargin == Decimal(string: "0.40")!)
        #expect(etsyPricing.profitMargin == Decimal(string: "0.25")!)
    }

    // MARK: - PlatformType Constants

    @Test("Etsy locked fees are correct")
    func etsyLockedFees() {
        #expect(PlatformType.etsy.lockedTransactionFee == Decimal(string: "0.095")!)
        #expect(PlatformType.etsy.lockedFixedFee == Decimal(string: "0.45")!)
        #expect(PlatformType.etsy.lockedMarketingFeeRate == Decimal(string: "0.15")!)
    }

    @Test("General has no locked fees — all return nil")
    func generalHasNoLockedFees() {
        #expect(PlatformType.general.lockedTransactionFee == nil)
        #expect(PlatformType.general.lockedFixedFee == nil)
        #expect(PlatformType.general.lockedMarketingFeeRate == nil)
    }

    @Test("Editability flags are correct per platform")
    func editabilityFlags() {
        // Transaction fee: only General is editable
        #expect(PlatformType.general.isTransactionFeeEditable == true)
        #expect(PlatformType.etsy.isTransactionFeeEditable == false)
        #expect(PlatformType.shopify.isTransactionFeeEditable == false)
        #expect(PlatformType.amazon.isTransactionFeeEditable == false)

        // Fixed fee: only General is editable
        #expect(PlatformType.general.isFixedFeeEditable == true)
        #expect(PlatformType.etsy.isFixedFeeEditable == false)
        #expect(PlatformType.shopify.isFixedFeeEditable == false)
        #expect(PlatformType.amazon.isFixedFeeEditable == false)

        // Marketing fee rate: editable on all except Etsy
        #expect(PlatformType.general.isMarketingFeeRateEditable == true)
        #expect(PlatformType.etsy.isMarketingFeeRateEditable == false)
        #expect(PlatformType.shopify.isMarketingFeeRateEditable == true)
        #expect(PlatformType.amazon.isMarketingFeeRateEditable == true)
    }

    // MARK: - CostingEngine: effectiveMarketingRate

    @Test("effectiveMarketingRate calculates rate × frequency")
    func effectiveMarketingRateCalculation() {
        let result = CostingEngine.effectiveMarketingRate(
            marketingFeeRate: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!
        )
        #expect(result == Decimal(string: "0.03")!)
    }

    // MARK: - CostingEngine: targetRetailPrice

    @Test("targetRetailPrice General — known inputs produce expected output")
    func targetRetailPriceGeneral() {
        // Production cost $20, no fixed fee, 5% transaction, 0% marketing, 30% margin
        // Denominator = 1 - (0.05 + 0 + 0.30) = 0.65
        // Target = $20 / 0.65 = $30.769230...
        let result = CostingEngine.targetRetailPrice(
            productionCost: 20,
            transactionFee: Decimal(string: "0.05")!,
            fixedFee: 0,
            marketingFeeRate: 0,
            percentSalesFromMarketing: 0,
            profitMargin: Decimal(string: "0.30")!
        )
        #expect(result != nil)
        // 20 / 0.65 = 400/13
        let expected = Decimal(20) / Decimal(string: "0.65")!
        #expect(result == expected)
    }

    @Test("targetRetailPrice Etsy — locked fees with marketing frequency")
    func targetRetailPriceEtsy() {
        // Production cost $20, fixed $0.45, transaction 9.5%, marketing 15% × 20% = 3%, margin 30%
        // Total % fees = 0.095 + 0.03 = 0.125
        // Denominator = 1 - (0.125 + 0.30) = 0.575
        // Target = ($20 + $0.45) / 0.575 = $20.45 / 0.575
        let result = CostingEngine.targetRetailPrice(
            productionCost: 20,
            transactionFee: Decimal(string: "0.095")!,
            fixedFee: Decimal(string: "0.45")!,
            marketingFeeRate: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            profitMargin: Decimal(string: "0.30")!
        )
        #expect(result != nil)
        let expected = Decimal(string: "20.45")! / Decimal(string: "0.575")!
        #expect(result == expected)
    }

    @Test("targetRetailPrice returns nil when fees + margin ≥ 100%")
    func targetRetailPriceOverflow() {
        // 70% transaction + 30% margin = 100% → denominator = 0 → nil
        let atExact = CostingEngine.targetRetailPrice(
            productionCost: 20,
            transactionFee: Decimal(string: "0.70")!,
            fixedFee: 0,
            marketingFeeRate: 0,
            percentSalesFromMarketing: 0,
            profitMargin: Decimal(string: "0.30")!
        )
        #expect(atExact == nil)

        // 80% transaction + 30% margin = 110% → denominator < 0 → nil
        let over = CostingEngine.targetRetailPrice(
            productionCost: 20,
            transactionFee: Decimal(string: "0.80")!,
            fixedFee: 0,
            marketingFeeRate: 0,
            percentSalesFromMarketing: 0,
            profitMargin: Decimal(string: "0.30")!
        )
        #expect(over == nil)

        // 69% + 30% = 99% → should succeed
        let under = CostingEngine.targetRetailPrice(
            productionCost: 20,
            transactionFee: Decimal(string: "0.69")!,
            fixedFee: 0,
            marketingFeeRate: 0,
            percentSalesFromMarketing: 0,
            profitMargin: Decimal(string: "0.30")!
        )
        #expect(under != nil)
    }

    @Test("resolvedFees uses locked constants over user values for Etsy")
    func resolvedFeesAppliesLockedConstants() {
        // Pass user values that differ from Etsy's locked constants
        let fees = CostingEngine.resolvedFees(
            platformType: .etsy,
            userTransactionFee: Decimal(string: "0.01")!,       // should be overridden to 0.095
            userFixedFee: Decimal(string: "0.10")!,             // should be overridden to 0.45
            userMarketingFeeRate: Decimal(string: "0.05")!,     // should be overridden to 0.15
            userPercentSalesFromMarketing: Decimal(string: "0.25")!, // stays as-is
            userProfitMargin: Decimal(string: "0.35")!          // stays as-is
        )

        #expect(fees.transactionFee == Decimal(string: "0.095")!)
        #expect(fees.fixedFee == Decimal(string: "0.45")!)
        #expect(fees.marketingFeeRate == Decimal(string: "0.15")!)
        #expect(fees.percentSalesFromMarketing == Decimal(string: "0.25")!)
        #expect(fees.profitMargin == Decimal(string: "0.35")!)
    }

    // MARK: - Product Duplication Copies ProductPricing

    @Test("Duplicate product copies ProductPricing entries with correct values")
    func duplicateProductCopiesProductPricing() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let source = Product(title: "Original")
        let pricing = ProductPricing(
            product: source,
            platformType: .general,
            transactionFeePercentage: Decimal(string: "0.05")!,
            fixedFeePerSale: Decimal(string: "1.00")!,
            marketingFeeRate: Decimal(string: "0.08")!,
            percentSalesFromMarketing: Decimal(string: "0.30")!,
            profitMargin: Decimal(string: "0.35")!
        )

        ctx.insert(source)
        ctx.insert(pricing)
        source.productPricings.append(pricing)
        try ctx.save()

        // --- Duplicate (mirrors ProductListView.duplicateProduct logic) ---
        let copy = Product(title: "\(source.title) (Copy)")
        ctx.insert(copy)

        for srcPricing in source.productPricings {
            let newPricing = ProductPricing(
                product: copy,
                platformType: srcPricing.platformType,
                transactionFeePercentage: srcPricing.transactionFeePercentage,
                fixedFeePerSale: srcPricing.fixedFeePerSale,
                marketingFeeRate: srcPricing.marketingFeeRate,
                percentSalesFromMarketing: srcPricing.percentSalesFromMarketing,
                profitMargin: srcPricing.profitMargin
            )
            ctx.insert(newPricing)
        }
        try ctx.save()

        // --- Assertions ---
        let copied = try ctx.fetch(FetchDescriptor<Product>()).first { $0.title == "Original (Copy)" }!
        #expect(copied.productPricings.count == 1)

        let copiedPricing = copied.productPricings[0]
        #expect(copiedPricing.platformType == .general)
        #expect(copiedPricing.transactionFeePercentage == Decimal(string: "0.05")!)
        #expect(copiedPricing.fixedFeePerSale == Decimal(string: "1.00")!)
        #expect(copiedPricing.marketingFeeRate == Decimal(string: "0.08")!)
        #expect(copiedPricing.percentSalesFromMarketing == Decimal(string: "0.30")!)
        #expect(copiedPricing.profitMargin == Decimal(string: "0.35")!)

        // Changing copy's pricing should not affect original
        copiedPricing.profitMargin = Decimal(string: "0.50")!
        try ctx.save()

        #expect(source.productPricings[0].profitMargin == Decimal(string: "0.35")!)
        #expect(copiedPricing.profitMargin == Decimal(string: "0.50")!)
    }

    @Test("Duplicate product with no pricing overrides duplicates cleanly")
    func duplicateProductWithNoPricingOverrides() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let source = Product(title: "No Pricing")
        ctx.insert(source)
        try ctx.save()

        #expect(source.productPricings.isEmpty)

        // Duplicate — no pricing to copy
        let copy = Product(title: "\(source.title) (Copy)")
        ctx.insert(copy)

        for srcPricing in source.productPricings {
            let newPricing = ProductPricing(
                product: copy,
                platformType: srcPricing.platformType,
                transactionFeePercentage: srcPricing.transactionFeePercentage,
                fixedFeePerSale: srcPricing.fixedFeePerSale,
                marketingFeeRate: srcPricing.marketingFeeRate,
                percentSalesFromMarketing: srcPricing.percentSalesFromMarketing,
                profitMargin: srcPricing.profitMargin
            )
            ctx.insert(newPricing)
        }
        try ctx.save()

        let copied = try ctx.fetch(FetchDescriptor<Product>()).first { $0.title == "No Pricing (Copy)" }!
        #expect(copied.productPricings.isEmpty)
    }

    // MARK: - CostingEngine: Model Overload

    @Test("targetRetailPrice model overload matches raw-value overload")
    func targetRetailPriceModelOverloadMatchesRawValue() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Product with known costs: $10 labor (buffered) + $5 material (buffered) + $3 shipping = $18
        let product = Product(title: "Test", shippingCost: 3, materialBuffer: 0, laborBuffer: 0)
        let step = WorkStep(title: "Step", recordedTime: 3600, batchUnitsCompleted: 1)
        let link = ProductWorkStep(product: product, workStep: step, sortOrder: 0, unitsRequiredPerProduct: 1, laborRate: 10)
        let material = Material(title: "Mat", bulkCost: 5, bulkQuantity: 1)
        let matLink = ProductMaterial(product: product, material: material, sortOrder: 0, unitsRequiredPerProduct: 1)

        product.productWorkSteps.append(link)
        step.productWorkSteps.append(link)
        product.productMaterials.append(matLink)
        material.productMaterials.append(matLink)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(link)
        ctx.insert(material)
        ctx.insert(matLink)
        try ctx.save()

        let productionCost = CostingEngine.totalProductionCost(product: product)
        // $10 labor + $5 material + $3 shipping = $18
        #expect(productionCost == 18)

        let rawResult = CostingEngine.targetRetailPrice(
            productionCost: productionCost,
            transactionFee: Decimal(string: "0.095")!,
            fixedFee: Decimal(string: "0.45")!,
            marketingFeeRate: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            profitMargin: Decimal(string: "0.30")!
        )

        let modelResult = CostingEngine.targetRetailPrice(
            product: product,
            transactionFee: Decimal(string: "0.095")!,
            fixedFee: Decimal(string: "0.45")!,
            marketingFeeRate: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            profitMargin: Decimal(string: "0.30")!
        )

        #expect(rawResult != nil)
        #expect(modelResult != nil)
        #expect(rawResult == modelResult)
    }
}
