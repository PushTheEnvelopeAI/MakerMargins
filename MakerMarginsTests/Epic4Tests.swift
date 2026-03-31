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
            platformFee: Decimal(string: "0.05")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            marketingFee: Decimal(string: "0.10")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            profitMargin: Decimal(string: "0.35")!
        )
        ctx.insert(profile)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PlatformFeeProfile>())
        #expect(fetched.count == 1)
        #expect(fetched[0].platformFee == Decimal(string: "0.05")!)
        #expect(fetched[0].paymentProcessingFee == Decimal(string: "0.03")!)
        #expect(fetched[0].marketingFee == Decimal(string: "0.10")!)
        #expect(fetched[0].percentSalesFromMarketing == Decimal(string: "0.20")!)
        #expect(fetched[0].profitMargin == Decimal(string: "0.35")!)
    }

    @Test("PlatformFeeProfile defaults are correct")
    func platformFeeProfileDefaults() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let profile = PlatformFeeProfile()
        ctx.insert(profile)
        try ctx.save()

        #expect(profile.platformFee == 0)
        #expect(profile.paymentProcessingFee == 0)
        #expect(profile.marketingFee == 0)
        #expect(profile.percentSalesFromMarketing == 0)
        #expect(profile.profitMargin == Decimal(string: "0.30")!)
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
            platformFee: Decimal(string: "0.03")!,
            paymentProcessingFee: Decimal(string: "0.029")!,
            marketingFee: Decimal(string: "0.10")!,
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
        #expect(fetched[0].platformFee == Decimal(string: "0.03")!)
        #expect(fetched[0].paymentProcessingFee == Decimal(string: "0.029")!)
        #expect(fetched[0].marketingFee == Decimal(string: "0.10")!)
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
        let profile = PlatformFeeProfile()

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

        generalPricing.profitMargin = Decimal(string: "0.40")!
        try ctx.save()

        #expect(generalPricing.profitMargin == Decimal(string: "0.40")!)
        #expect(etsyPricing.profitMargin == Decimal(string: "0.25")!)
    }

    // MARK: - PlatformType Constants

    @Test("Etsy locked fees are correct")
    func etsyLockedFees() {
        #expect(PlatformType.etsy.lockedPlatformFee == Decimal(string: "0.065")!)
        #expect(PlatformType.etsy.lockedPaymentProcessingFee == Decimal(string: "0.03")!)
        #expect(PlatformType.etsy.lockedPaymentProcessingFixed == Decimal(string: "0.25")!)
        #expect(PlatformType.etsy.lockedMarketingFee == Decimal(string: "0.15")!)
    }

    @Test("Shopify locked fees are correct")
    func shopifyLockedFees() {
        #expect(PlatformType.shopify.lockedPlatformFee == Decimal(0))
        #expect(PlatformType.shopify.lockedPaymentProcessingFee == Decimal(string: "0.029")!)
        #expect(PlatformType.shopify.lockedPaymentProcessingFixed == Decimal(string: "0.30")!)
        #expect(PlatformType.shopify.lockedMarketingFee == nil)
    }

    @Test("Amazon locked fees are correct")
    func amazonLockedFees() {
        #expect(PlatformType.amazon.lockedPlatformFee == Decimal(string: "0.15")!)
        #expect(PlatformType.amazon.lockedPaymentProcessingFee == Decimal(0))
        #expect(PlatformType.amazon.lockedPaymentProcessingFixed == Decimal(0))
        #expect(PlatformType.amazon.lockedMarketingFee == nil)
    }

    @Test("General has no locked fees — all return nil")
    func generalHasNoLockedFees() {
        #expect(PlatformType.general.lockedPlatformFee == nil)
        #expect(PlatformType.general.lockedPaymentProcessingFee == nil)
        #expect(PlatformType.general.lockedPaymentProcessingFixed == Decimal(0))
        #expect(PlatformType.general.lockedMarketingFee == nil)
    }

    @Test("Editability flags are correct per platform")
    func editabilityFlags() {
        // Platform fee: only General editable
        #expect(PlatformType.general.isPlatformFeeEditable == true)
        #expect(PlatformType.etsy.isPlatformFeeEditable == false)
        #expect(PlatformType.shopify.isPlatformFeeEditable == false)
        #expect(PlatformType.amazon.isPlatformFeeEditable == false)

        // Payment processing: only General editable
        #expect(PlatformType.general.isPaymentProcessingFeeEditable == true)
        #expect(PlatformType.etsy.isPaymentProcessingFeeEditable == false)
        #expect(PlatformType.shopify.isPaymentProcessingFeeEditable == false)
        #expect(PlatformType.amazon.isPaymentProcessingFeeEditable == false)

        // Marketing fee: editable on all except Etsy
        #expect(PlatformType.general.isMarketingFeeEditable == true)
        #expect(PlatformType.etsy.isMarketingFeeEditable == false)
        #expect(PlatformType.shopify.isMarketingFeeEditable == true)
        #expect(PlatformType.amazon.isMarketingFeeEditable == true)
    }

    @Test("Display helpers format locked fees correctly")
    func displayHelpers() {
        // Etsy: all three display strings present
        #expect(PlatformType.etsy.platformFeeDisplay == "6.5%")
        #expect(PlatformType.etsy.paymentProcessingDisplay == "3% + $0.25")
        #expect(PlatformType.etsy.marketingFeeDisplay == "15%")

        // Shopify: platform fee 0%, processing with fixed, no marketing display
        #expect(PlatformType.shopify.platformFeeDisplay == "0%")
        #expect(PlatformType.shopify.paymentProcessingDisplay == "2.9% + $0.30")
        #expect(PlatformType.shopify.marketingFeeDisplay == nil)

        // Amazon: platform fee 15%, processing 0%, no marketing display
        #expect(PlatformType.amazon.platformFeeDisplay == "15%")
        #expect(PlatformType.amazon.paymentProcessingDisplay == "0%")
        #expect(PlatformType.amazon.marketingFeeDisplay == nil)

        // General: all nil (all editable)
        #expect(PlatformType.general.platformFeeDisplay == nil)
        #expect(PlatformType.general.paymentProcessingDisplay == nil)
        #expect(PlatformType.general.marketingFeeDisplay == nil)
    }

    // MARK: - CostingEngine: effectiveMarketingRate

    @Test("effectiveMarketingRate calculates rate × frequency")
    func effectiveMarketingRateCalculation() {
        let result = CostingEngine.effectiveMarketingRate(
            marketingFee: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!
        )
        #expect(result == Decimal(string: "0.03")!)
    }

    // MARK: - CostingEngine: targetRetailPrice

    @Test("targetRetailPrice General — known inputs produce expected output")
    func targetRetailPriceGeneral() {
        // Production cost $20, 3% platform + 2% processing + $0 fixed, 0% marketing, 30% margin
        // Total % fees = 0.03 + 0.02 = 0.05
        // Denominator = 1 - (0.05 + 0.30) = 0.65
        // Target = $20 / 0.65
        let result = CostingEngine.targetRetailPrice(
            productionCost: 20,
            platformFee: Decimal(string: "0.03")!,
            paymentProcessingFee: Decimal(string: "0.02")!,
            paymentProcessingFixed: 0,
            marketingFee: 0,
            percentSalesFromMarketing: 0,
            profitMargin: Decimal(string: "0.30")!
        )
        #expect(result != nil)
        let expected = Decimal(20) / Decimal(string: "0.65")!
        #expect(result == expected)
    }

    @Test("targetRetailPrice Etsy — locked fees with marketing frequency")
    func targetRetailPriceEtsy() {
        // Production cost $20, Etsy: 6.5% platform + 3% processing + $0.25 fixed, 15% marketing × 20% = 3%, 30% margin
        // Total % fees = 0.065 + 0.03 + 0.03 = 0.125
        // Denominator = 1 - (0.125 + 0.30) = 0.575
        // Target = ($20 + $0.25) / 0.575 = $20.25 / 0.575
        let result = CostingEngine.targetRetailPrice(
            productionCost: 20,
            platformFee: Decimal(string: "0.065")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            paymentProcessingFixed: Decimal(string: "0.25")!,
            marketingFee: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            profitMargin: Decimal(string: "0.30")!
        )
        #expect(result != nil)
        let expected = Decimal(string: "20.25")! / Decimal(string: "0.575")!
        #expect(result == expected)
    }

    @Test("targetRetailPrice returns nil when fees + margin ≥ 100%")
    func targetRetailPriceOverflow() {
        // 40% platform + 30% processing + 0% marketing + 30% margin = 100% → nil
        let atExact = CostingEngine.targetRetailPrice(
            productionCost: 20,
            platformFee: Decimal(string: "0.40")!,
            paymentProcessingFee: Decimal(string: "0.30")!,
            paymentProcessingFixed: 0,
            marketingFee: 0,
            percentSalesFromMarketing: 0,
            profitMargin: Decimal(string: "0.30")!
        )
        #expect(atExact == nil)

        // 39% + 30% + 30% = 99% → should succeed
        let under = CostingEngine.targetRetailPrice(
            productionCost: 20,
            platformFee: Decimal(string: "0.39")!,
            paymentProcessingFee: Decimal(string: "0.30")!,
            paymentProcessingFixed: 0,
            marketingFee: 0,
            percentSalesFromMarketing: 0,
            profitMargin: Decimal(string: "0.30")!
        )
        #expect(under != nil)
    }

    @Test("resolvedFees uses locked constants over user values for Etsy")
    func resolvedFeesAppliesLockedConstants() {
        let fees = CostingEngine.resolvedFees(
            platformType: .etsy,
            userPlatformFee: Decimal(string: "0.01")!,
            userPaymentProcessingFee: Decimal(string: "0.01")!,
            userMarketingFee: Decimal(string: "0.05")!,
            userPercentSalesFromMarketing: Decimal(string: "0.25")!,
            userProfitMargin: Decimal(string: "0.35")!
        )

        // Locked values override user values
        #expect(fees.platformFee == Decimal(string: "0.065")!)
        #expect(fees.paymentProcessingFee == Decimal(string: "0.03")!)
        #expect(fees.paymentProcessingFixed == Decimal(string: "0.25")!)
        #expect(fees.marketingFee == Decimal(string: "0.15")!)
        // User values pass through
        #expect(fees.percentSalesFromMarketing == Decimal(string: "0.25")!)
        #expect(fees.profitMargin == Decimal(string: "0.35")!)
    }

    @Test("resolvedFees uses user values for General (no locked constants)")
    func resolvedFeesUsesUserValuesForGeneral() {
        let fees = CostingEngine.resolvedFees(
            platformType: .general,
            userPlatformFee: Decimal(string: "0.05")!,
            userPaymentProcessingFee: Decimal(string: "0.03")!,
            userMarketingFee: Decimal(string: "0.08")!,
            userPercentSalesFromMarketing: Decimal(string: "0.15")!,
            userProfitMargin: Decimal(string: "0.25")!
        )

        #expect(fees.platformFee == Decimal(string: "0.05")!)
        #expect(fees.paymentProcessingFee == Decimal(string: "0.03")!)
        #expect(fees.paymentProcessingFixed == Decimal(0))
        #expect(fees.marketingFee == Decimal(string: "0.08")!)
        #expect(fees.percentSalesFromMarketing == Decimal(string: "0.15")!)
        #expect(fees.profitMargin == Decimal(string: "0.25")!)
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
            platformFee: Decimal(string: "0.05")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            marketingFee: Decimal(string: "0.08")!,
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
                platformFee: srcPricing.platformFee,
                paymentProcessingFee: srcPricing.paymentProcessingFee,
                marketingFee: srcPricing.marketingFee,
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
        #expect(copiedPricing.platformFee == Decimal(string: "0.05")!)
        #expect(copiedPricing.paymentProcessingFee == Decimal(string: "0.03")!)
        #expect(copiedPricing.marketingFee == Decimal(string: "0.08")!)
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

        let copy = Product(title: "\(source.title) (Copy)")
        ctx.insert(copy)

        for srcPricing in source.productPricings {
            let newPricing = ProductPricing(
                product: copy,
                platformType: srcPricing.platformType,
                platformFee: srcPricing.platformFee,
                paymentProcessingFee: srcPricing.paymentProcessingFee,
                marketingFee: srcPricing.marketingFee,
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

        // Product with known costs: $10 labor + $5 material + $3 shipping = $18
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

        let cost = CostingEngine.totalProductionCost(product: product)
        #expect(cost == 18)

        let rawResult = CostingEngine.targetRetailPrice(
            productionCost: cost,
            platformFee: Decimal(string: "0.065")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            paymentProcessingFixed: Decimal(string: "0.25")!,
            marketingFee: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            profitMargin: Decimal(string: "0.30")!
        )

        let modelResult = CostingEngine.targetRetailPrice(
            product: product,
            platformFee: Decimal(string: "0.065")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            paymentProcessingFixed: Decimal(string: "0.25")!,
            marketingFee: Decimal(string: "0.15")!,
            percentSalesFromMarketing: Decimal(string: "0.20")!,
            profitMargin: Decimal(string: "0.30")!
        )

        #expect(rawResult != nil)
        #expect(modelResult != nil)
        #expect(rawResult == modelResult)
    }
}
