// RefactorTests.swift
// MakerMarginsTests
//
// Tests for gaps identified during the production readiness audit.
// Covers: formatters, AppearanceManager, cross-platform fees,
// buffered costs, negative inputs, and new Phase 3 engine functions.

import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import MakerMargins

@MainActor
struct RefactorTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Product.self, Category.self, WorkStep.self, Material.self,
            PlatformFeeProfile.self, ProductWorkStep.self, ProductMaterial.self, ProductPricing.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - 6.1 Formatter Tests

    @Test("formatDuration: zero seconds")
    func formatDurationZero() {
        #expect(CostingEngine.formatDuration(0) == "0m 0s")
    }

    @Test("formatDuration: 1h 1m 1s")
    func formatDuration3661() {
        #expect(CostingEngine.formatDuration(3661) == "1h 1m 1s")
    }

    @Test("formatDuration: 24 hours")
    func formatDuration86400() {
        #expect(CostingEngine.formatDuration(86400) == "24h 0m 0s")
    }

    @Test("formatHours: zero")
    func formatHoursZero() {
        #expect(CostingEngine.formatHours(0) == "0.00")
    }

    @Test("formatHours: precision with trailing zero stripping")
    func formatHoursPrecision() {
        #expect(CostingEngine.formatHours(Decimal(string: "0.12345")!) == "0.1235")
    }

    @Test("formatHours: keeps minimum 2 decimal places")
    func formatHoursMinDecimals() {
        #expect(CostingEngine.formatHours(Decimal(string: "1.50")!) == "1.50")
    }

    @Test("formatHours: whole number gets .00")
    func formatHoursWhole() {
        #expect(CostingEngine.formatHours(10) == "10.00")
    }

    @Test("formatStopwatchTime: zero")
    func formatStopwatchZero() {
        #expect(CostingEngine.formatStopwatchTime(0) == "00:00.0")
    }

    @Test("formatStopwatchTime: with hours")
    func formatStopwatchWithHours() {
        #expect(CostingEngine.formatStopwatchTime(3661.5) == "1:01:01.5")
    }

    @Test("formatStopwatchTime: minutes and seconds only")
    func formatStopwatchMinutesOnly() {
        #expect(CostingEngine.formatStopwatchTime(125.5) == "02:05.5")
    }

    // MARK: - 6.2 AppearanceManager Tests

    @Test("AppearanceManager default setting is system")
    func appearanceDefaultIsSystem() {
        // Clear any persisted value first
        UserDefaults.standard.removeObject(forKey: "appearanceSetting")
        let manager = AppearanceManager()
        #expect(manager.setting == .system)
    }

    @Test("AppearanceManager resolvedColorScheme returns nil for system")
    func appearanceSystemReturnsNil() {
        let manager = AppearanceManager()
        manager.setting = .system
        #expect(manager.resolvedColorScheme == nil)
    }

    @Test("AppearanceManager resolvedColorScheme returns .light for light")
    func appearanceLightReturnsLight() {
        let manager = AppearanceManager()
        manager.setting = .light
        #expect(manager.resolvedColorScheme == .light)
    }

    @Test("AppearanceManager resolvedColorScheme returns .dark for dark")
    func appearanceDarkReturnsDark() {
        let manager = AppearanceManager()
        manager.setting = .dark
        #expect(manager.resolvedColorScheme == .dark)
    }

    @Test("AppearanceManager persists setting to UserDefaults")
    func appearancePersistence() {
        let manager = AppearanceManager()
        manager.setting = .dark
        let raw = UserDefaults.standard.string(forKey: "appearanceSetting")
        #expect(raw == "dark")
        // Clean up
        UserDefaults.standard.removeObject(forKey: "appearanceSetting")
    }

    // MARK: - 6.3 Cross-Platform resolvedFees

    @Test("resolvedFees for Shopify applies locked platform + processing, user marketing")
    func resolvedFeesShopify() {
        let fees = CostingEngine.resolvedFees(
            platformType: .shopify,
            userPlatformFee: Decimal(string: "0.10")!,
            userPaymentProcessingFee: Decimal(string: "0.10")!,
            userMarketingFee: Decimal(string: "0.08")!,
            userPercentSalesFromMarketing: Decimal(string: "0.20")!,
            userProfitMargin: Decimal(string: "0.30")!
        )
        // Shopify: 0% platform (locked), 2.9% + $0.30 processing (locked), marketing editable
        #expect(fees.platformFee == 0)
        #expect(fees.paymentProcessingFee == Decimal(string: "0.029")!)
        #expect(fees.paymentProcessingFixed == Decimal(string: "0.30")!)
        #expect(fees.marketingFee == Decimal(string: "0.08")!)  // user value (editable)
    }

    @Test("resolvedFees for Amazon applies locked platform fee, user marketing")
    func resolvedFeesAmazon() {
        let fees = CostingEngine.resolvedFees(
            platformType: .amazon,
            userPlatformFee: Decimal(string: "0.05")!,
            userPaymentProcessingFee: Decimal(string: "0.05")!,
            userMarketingFee: Decimal(string: "0.10")!,
            userPercentSalesFromMarketing: Decimal(string: "0.15")!,
            userProfitMargin: Decimal(string: "0.25")!
        )
        // Amazon: 15% referral (locked), 0% processing (locked), marketing editable
        #expect(fees.platformFee == Decimal(string: "0.15")!)
        #expect(fees.paymentProcessingFee == 0)
        #expect(fees.paymentProcessingFixed == 0)
        #expect(fees.marketingFee == Decimal(string: "0.10")!)  // user value (editable)
    }

    // MARK: - 6.4 Cross-Platform Portfolio

    @Test("Portfolio snapshot with Etsy pricing uses Etsy fee structure")
    func portfolioSnapshotEtsy() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let product = Product(title: "Test", shippingCost: 5)
        ctx.insert(product)

        let step = WorkStep(title: "Step", recordedTime: 3600, batchUnitsCompleted: 1)
        ctx.insert(step)
        let link = ProductWorkStep(product: product, workStep: step, laborRate: 20)
        ctx.insert(link)

        let pricing = ProductPricing(
            product: product, platformType: .etsy,
            platformFee: 0, paymentProcessingFee: 0,
            marketingFee: 0, percentSalesFromMarketing: 0,
            profitMargin: Decimal(string: "0.30")!,
            actualPrice: 50, actualShippingCharge: 5
        )
        ctx.insert(pricing)

        let snap = CostingEngine.productSnapshot(product: product, platform: .etsy)
        #expect(snap.hasPricing == true)
        // Etsy locks 6.5% platform + 3% processing + $0.25 fixed
        // Fees should reflect Etsy rates, not user zeros
        #expect(snap.profit < 50)  // Profit must be less than revenue after fees
        #expect(snap.earnings > 0)  // Earnings = profit + labor
    }

    @Test("Portfolio averages with Etsy platform computes correctly")
    func portfolioAveragesEtsy() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let p1 = Product(title: "P1", shippingCost: 5)
        let p2 = Product(title: "P2", shippingCost: 3)
        ctx.insert(p1)
        ctx.insert(p2)

        let pricing1 = ProductPricing(
            product: p1, platformType: .etsy,
            profitMargin: Decimal(string: "0.30")!,
            actualPrice: 40, actualShippingCharge: 5
        )
        let pricing2 = ProductPricing(
            product: p2, platformType: .etsy,
            profitMargin: Decimal(string: "0.30")!,
            actualPrice: 60, actualShippingCharge: 0
        )
        ctx.insert(pricing1)
        ctx.insert(pricing2)

        let snaps = CostingEngine.portfolioSnapshots(products: [p1, p2], platform: .etsy)
        let avg = CostingEngine.portfolioAverages(snapshots: snaps)
        #expect(avg.pricedCount == 2)
        #expect(avg.totalCount == 2)
        #expect(avg.avgEarnings > 0)
    }

    // MARK: - 6.5 Buffered Cost Isolation

    @Test("totalLaborCostBuffered with known values")
    func laborCostBufferedKnown() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let product = Product(title: "Test", laborBuffer: Decimal(string: "0.10")!)
        ctx.insert(product)

        let step = WorkStep(title: "Step", recordedTime: 3600, batchUnitsCompleted: 1)
        ctx.insert(step)
        let link = ProductWorkStep(product: product, workStep: step, laborRate: 20)
        ctx.insert(link)

        // Labor cost = 1 hour * 20 = 20. Buffered = 20 * 1.10 = 22
        let buffered = CostingEngine.totalLaborCostBuffered(product: product)
        #expect(buffered == 22)
    }

    @Test("totalLaborCostBuffered with zero buffer")
    func laborCostBufferedZero() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let product = Product(title: "Test", laborBuffer: 0)
        ctx.insert(product)

        let step = WorkStep(title: "Step", recordedTime: 3600, batchUnitsCompleted: 1)
        ctx.insert(step)
        let link = ProductWorkStep(product: product, workStep: step, laborRate: 15)
        ctx.insert(link)

        let buffered = CostingEngine.totalLaborCostBuffered(product: product)
        let raw = CostingEngine.totalLaborCost(product: product)
        #expect(buffered == raw)
    }

    @Test("totalMaterialCostBuffered with known values")
    func materialCostBufferedKnown() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let product = Product(title: "Test", materialBuffer: Decimal(string: "0.10")!)
        ctx.insert(product)

        let mat = Material(title: "Wood", bulkCost: 40, bulkQuantity: 4)
        ctx.insert(mat)
        let link = ProductMaterial(product: product, material: mat, unitsRequiredPerProduct: 2)
        ctx.insert(link)

        // Unit cost = 40/4 = 10. Line cost = 10 * 2 = 20. Buffered = 20 * 1.10 = 22
        let buffered = CostingEngine.totalMaterialCostBuffered(product: product)
        #expect(buffered == 22)
    }

    @Test("totalMaterialCostBuffered with zero buffer equals raw cost")
    func materialCostBufferedZero() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let product = Product(title: "Test", materialBuffer: 0)
        ctx.insert(product)

        let mat = Material(title: "Wood", bulkCost: 30, bulkQuantity: 3)
        ctx.insert(mat)
        let link = ProductMaterial(product: product, material: mat)
        ctx.insert(link)

        let buffered = CostingEngine.totalMaterialCostBuffered(product: product)
        let raw = CostingEngine.totalMaterialCost(product: product)
        #expect(buffered == raw)
    }

    // MARK: - 6.6 Negative Input Tests

    @Test("stepLaborCost with negative laborRate produces negative cost")
    func negativeLaborRate() {
        let cost = CostingEngine.stepLaborCost(
            recordedTime: 3600, batchUnitsCompleted: 1,
            unitsRequiredPerProduct: 1, laborRate: -10
        )
        #expect(cost == -10)  // Negative rate → negative cost (no guard)
    }

    @Test("materialLineCost with negative bulkCost produces negative unit cost")
    func negativeBulkCost() {
        let lineCost = CostingEngine.materialLineCost(
            bulkCost: -20, bulkQuantity: 4, unitsRequiredPerProduct: 2
        )
        // Unit cost = -20/4 = -5. Line cost = -5 * 2 = -10
        #expect(lineCost == -10)
    }

    @Test("totalProductionCost with negative buffer reduces below raw cost")
    func negativeBuffer() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let product = Product(title: "Test", shippingCost: 0, materialBuffer: 0, laborBuffer: Decimal(string: "-0.50")!)
        ctx.insert(product)

        let step = WorkStep(title: "Step", recordedTime: 3600, batchUnitsCompleted: 1)
        ctx.insert(step)
        let link = ProductWorkStep(product: product, workStep: step, laborRate: 20)
        ctx.insert(link)

        // Labor = 20. Buffered = 20 * (1 + (-0.50)) = 20 * 0.50 = 10
        let total = CostingEngine.totalProductionCost(product: product)
        #expect(total == 10)
    }

    // MARK: - 6.7 New Engine Function Tests (Phase 3)

    @Test("batchLaborCostBuffered multiplies by batch size")
    func batchLaborCostBuffered() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let product = Product(title: "Test", laborBuffer: Decimal(string: "0.10")!)
        ctx.insert(product)
        let step = WorkStep(title: "Step", recordedTime: 3600, batchUnitsCompleted: 1)
        ctx.insert(step)
        let link = ProductWorkStep(product: product, workStep: step, laborRate: 20)
        ctx.insert(link)

        let perUnit = CostingEngine.totalLaborCostBuffered(product: product)
        let batch = CostingEngine.batchLaborCostBuffered(product: product, batchSize: 10)
        #expect(batch == perUnit * 10)
    }

    @Test("batchMaterialCostBuffered multiplies by batch size")
    func batchMaterialCostBuffered() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let product = Product(title: "Test", materialBuffer: Decimal(string: "0.05")!)
        ctx.insert(product)
        let mat = Material(title: "Mat", bulkCost: 20, bulkQuantity: 4)
        ctx.insert(mat)
        let link = ProductMaterial(product: product, material: mat, unitsRequiredPerProduct: 2)
        ctx.insert(link)

        let perUnit = CostingEngine.totalMaterialCostBuffered(product: product)
        let batch = CostingEngine.batchMaterialCostBuffered(product: product, batchSize: 5)
        #expect(batch == perUnit * 5)
    }

    @Test("batchShippingCost multiplies by batch size")
    func batchShippingCost() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let product = Product(title: "Test", shippingCost: Decimal(string: "7.50")!)
        ctx.insert(product)

        let batch = CostingEngine.batchShippingCost(product: product, batchSize: 20)
        #expect(batch == Decimal(string: "150.00")!)
    }

    @Test("batchEarnings equals profit plus labor cost")
    func batchEarningsCalc() {
        let earnings = CostingEngine.batchEarnings(batchProfit: 50, batchLaborCostBuffered: 30)
        #expect(earnings == 80)
    }

    @Test("batchEarningsPerUnit divides by batch size")
    func batchEarningsPerUnit() {
        let perUnit = CostingEngine.batchEarningsPerUnit(batchEarnings: 100, batchSize: 10)
        #expect(perUnit == 10)
    }

    @Test("batchEarningsPerUnit returns nil for zero batch size")
    func batchEarningsPerUnitZero() {
        let perUnit = CostingEngine.batchEarningsPerUnit(batchEarnings: 100, batchSize: 0)
        #expect(perUnit == nil)
    }

    @Test("platformFeeAmount calculates correctly")
    func platformFeeAmountCalc() {
        let amount = CostingEngine.platformFeeAmount(grossRevenue: 100, platformFee: Decimal(string: "0.065")!)
        #expect(amount == Decimal(string: "6.5")!)
    }

    @Test("processingFeeAmount includes fixed component")
    func processingFeeAmountCalc() {
        let amount = CostingEngine.processingFeeAmount(
            grossRevenue: 100,
            processingFee: Decimal(string: "0.03")!,
            processingFixed: Decimal(string: "0.25")!
        )
        #expect(amount == Decimal(string: "3.25")!)
    }

    @Test("marketingFeeAmount calculates correctly")
    func marketingFeeAmountCalc() {
        let amount = CostingEngine.marketingFeeAmount(
            actualPrice: 80,
            effectiveMarketingRate: Decimal(string: "0.03")!
        )
        #expect(amount == Decimal(string: "2.4")!)
    }

    @Test("totalPercentFees sums all fee percentages")
    func totalPercentFeesCalc() {
        let total = CostingEngine.totalPercentFees(
            platformFee: Decimal(string: "0.065")!,
            paymentProcessingFee: Decimal(string: "0.03")!,
            effectiveMarketing: Decimal(string: "0.03")!
        )
        #expect(total == Decimal(string: "0.125")!)
    }

    @Test("costBreakdownFractions with known values")
    func costBreakdownFractionsKnown() {
        let fractions = CostingEngine.costBreakdownFractions(
            laborCostBuffered: 50, materialCostBuffered: 30, shippingCost: 20
        )
        // Total = 100. Labor 50%, Material 30%, Shipping 20%
        #expect(abs(fractions.labor - 0.5) < 0.001)
        #expect(abs(fractions.material - 0.3) < 0.001)
        #expect(abs(fractions.shipping - 0.2) < 0.001)
    }

    @Test("costBreakdownFractions returns zeros when total is zero")
    func costBreakdownFractionsZero() {
        let fractions = CostingEngine.costBreakdownFractions(
            laborCostBuffered: 0, materialCostBuffered: 0, shippingCost: 0
        )
        #expect(fractions.labor == 0)
        #expect(fractions.material == 0)
        #expect(fractions.shipping == 0)
    }

    @Test("batchProductionCostExShipping multiplies by batch size")
    func batchProductionCostExShipping() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let product = Product(title: "Test", shippingCost: 10, materialBuffer: 0, laborBuffer: 0)
        ctx.insert(product)
        let step = WorkStep(title: "Step", recordedTime: 3600, batchUnitsCompleted: 1)
        ctx.insert(step)
        let link = ProductWorkStep(product: product, workStep: step, laborRate: 20)
        ctx.insert(link)

        let perUnit = CostingEngine.productionCostExShipping(product: product)
        let batch = CostingEngine.batchProductionCostExShipping(product: product, batchSize: 5)
        #expect(batch == perUnit * 5)
    }

    @Test("formatStopwatchTime negative seconds clamps to zero")
    func formatStopwatchNegative() {
        #expect(CostingEngine.formatStopwatchTime(-10) == "00:00.0")
    }
}
