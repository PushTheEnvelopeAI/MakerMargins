// CostingEngine.swift
// MakerMargins
//
// Central calculation handler for all costing and pricing logic.
// Pure logic — no state, no UI. Models are pure data; this is pure math.
//
// Model-based functions accept WorkStep/Product/Material objects for use in views.
// Raw-value overloads accept primitives for real-time form previews
// before a model is saved.

import Foundation

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

    // MARK: - Per-Step Product-Context Calculations

    /// Total labor hours for this step per finished product.
    static func laborHoursPerProduct(link: ProductWorkStep) -> Decimal {
        guard let step = link.workStep else { return 0 }
        return laborHoursPerProduct(
            recordedTime: step.recordedTime,
            batchUnitsCompleted: step.batchUnitsCompleted,
            unitsRequiredPerProduct: link.unitsRequiredPerProduct
        )
    }

    /// Raw-value overload for product-context previews.
    static func laborHoursPerProduct(
        recordedTime: TimeInterval,
        batchUnitsCompleted: Decimal,
        unitsRequiredPerProduct: Decimal
    ) -> Decimal {
        unitTimeHours(recordedTime: recordedTime, batchUnitsCompleted: batchUnitsCompleted)
            * unitsRequiredPerProduct
    }

    /// Labor cost for a single step per finished product.
    /// Uses laborRate from the ProductWorkStep join model (per-product rate).
    static func stepLaborCost(link: ProductWorkStep) -> Decimal {
        guard let step = link.workStep else { return 0 }
        return stepLaborCost(
            recordedTime: step.recordedTime,
            batchUnitsCompleted: step.batchUnitsCompleted,
            unitsRequiredPerProduct: link.unitsRequiredPerProduct,
            laborRate: link.laborRate
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

    // MARK: - Per-Material Calculations

    /// Cost per unit of material.
    /// Returns 0 if bulkQuantity is zero (division guard).
    static func materialUnitCost(material: Material) -> Decimal {
        materialUnitCost(
            bulkCost: material.bulkCost,
            bulkQuantity: material.bulkQuantity
        )
    }

    /// Raw-value overload for form previews.
    static func materialUnitCost(
        bulkCost: Decimal,
        bulkQuantity: Decimal
    ) -> Decimal {
        guard bulkQuantity != 0 else { return 0 }
        return bulkCost / bulkQuantity
    }

    /// Cost of a single material line item per finished product.
    /// materialLineCost = materialUnitCost * unitsRequiredPerProduct
    static func materialLineCost(material: Material) -> Decimal {
        materialLineCost(
            bulkCost: material.bulkCost,
            bulkQuantity: material.bulkQuantity,
            unitsRequiredPerProduct: material.defaultUnitsPerProduct
        )
    }

    /// Product-context overload — uses the join model's per-product units.
    static func materialLineCost(link: ProductMaterial) -> Decimal {
        guard let material = link.material else { return 0 }
        return materialLineCost(
            bulkCost: material.bulkCost,
            bulkQuantity: material.bulkQuantity,
            unitsRequiredPerProduct: link.unitsRequiredPerProduct
        )
    }

    /// Raw-value overload for form previews.
    static func materialLineCost(
        bulkCost: Decimal,
        bulkQuantity: Decimal,
        unitsRequiredPerProduct: Decimal
    ) -> Decimal {
        materialUnitCost(bulkCost: bulkCost, bulkQuantity: bulkQuantity) * unitsRequiredPerProduct
    }

    // MARK: - Product-Level Calculations

    /// Total labor cost across all work steps linked to a product.
    /// Uses per-product unitsRequiredPerProduct from each join model.
    static func totalLaborCost(product: Product) -> Decimal {
        product.productWorkSteps.reduce(Decimal.zero) { sum, link in
            sum + stepLaborCost(link: link)
        }
    }

    /// Total material cost across all materials linked to a product.
    /// Uses per-product unitsRequiredPerProduct from each join model.
    static func totalMaterialCost(product: Product) -> Decimal {
        product.productMaterials.reduce(Decimal.zero) { sum, link in
            sum + materialLineCost(link: link)
        }
    }

    /// Total labor cost with the product's labor buffer applied.
    static func totalLaborCostBuffered(product: Product) -> Decimal {
        totalLaborCost(product: product) * (1 + product.laborBuffer)
    }

    /// Total material cost with the product's material buffer applied.
    static func totalMaterialCostBuffered(product: Product) -> Decimal {
        totalMaterialCost(product: product) * (1 + product.materialBuffer)
    }

    /// Total production cost with per-section buffers applied.
    /// labor × (1 + laborBuffer) + material × (1 + materialBuffer) + shipping
    /// Shipping is never buffered.
    static func totalProductionCost(product: Product) -> Decimal {
        let laborBuffered = totalLaborCostBuffered(product: product)
        let materialBuffered = totalMaterialCostBuffered(product: product)
        return laborBuffered + materialBuffered + product.shippingCost
    }

    // MARK: - Target Price Calculations

    /// Effective marketing cost rate per sale (used internally by targetRetailPrice).
    /// Formula: marketingFee × percentSalesFromMarketing
    static func effectiveMarketingRate(
        marketingFee: Decimal,
        percentSalesFromMarketing: Decimal
    ) -> Decimal {
        marketingFee * percentSalesFromMarketing
    }

    /// Resolves the effective fee values for a platform, applying locked constants
    /// where the platform mandates them and user values where editable.
    /// Also returns the platform's fixed processing fee (always a locked constant).
    static func resolvedFees(
        platformType: PlatformType,
        userPlatformFee: Decimal,
        userPaymentProcessingFee: Decimal,
        userMarketingFee: Decimal,
        userPercentSalesFromMarketing: Decimal,
        userProfitMargin: Decimal
    ) -> (platformFee: Decimal, paymentProcessingFee: Decimal,
          paymentProcessingFixed: Decimal, marketingFee: Decimal,
          percentSalesFromMarketing: Decimal, profitMargin: Decimal) {
        (
            platformFee: platformType.lockedPlatformFee ?? userPlatformFee,
            paymentProcessingFee: platformType.lockedPaymentProcessingFee ?? userPaymentProcessingFee,
            paymentProcessingFixed: platformType.lockedPaymentProcessingFixed,
            marketingFee: platformType.lockedMarketingFee ?? userMarketingFee,
            percentSalesFromMarketing: userPercentSalesFromMarketing,
            profitMargin: userProfitMargin
        )
    }

    /// Target retail price given raw cost and fee values.
    ///
    /// Formula:
    ///   effectiveMarketing = marketingFee × percentSalesFromMarketing
    ///   totalPercentFees = platformFee + paymentProcessingFee + effectiveMarketing
    ///   targetPrice = (productionCost + paymentProcessingFixed) / (1 - (totalPercentFees + profitMargin))
    ///
    /// Returns nil if the denominator is zero or negative (fees + margin ≥ 100%).
    static func targetRetailPrice(
        productionCost: Decimal,
        platformFee: Decimal,
        paymentProcessingFee: Decimal,
        paymentProcessingFixed: Decimal,
        marketingFee: Decimal,
        percentSalesFromMarketing: Decimal,
        profitMargin: Decimal
    ) -> Decimal? {
        let marketing = effectiveMarketingRate(
            marketingFee: marketingFee,
            percentSalesFromMarketing: percentSalesFromMarketing
        )
        let totalPercentFees = platformFee + paymentProcessingFee + marketing
        let denominator = 1 - (totalPercentFees + profitMargin)
        guard denominator > 0 else { return nil }
        return (productionCost + paymentProcessingFixed) / denominator
    }

    /// Target retail price for a product given fee values.
    /// Computes production cost from the product, then delegates to the raw-value overload.
    static func targetRetailPrice(
        product: Product,
        platformFee: Decimal,
        paymentProcessingFee: Decimal,
        paymentProcessingFixed: Decimal,
        marketingFee: Decimal,
        percentSalesFromMarketing: Decimal,
        profitMargin: Decimal
    ) -> Decimal? {
        targetRetailPrice(
            productionCost: totalProductionCost(product: product),
            platformFee: platformFee,
            paymentProcessingFee: paymentProcessingFee,
            paymentProcessingFixed: paymentProcessingFixed,
            marketingFee: marketingFee,
            percentSalesFromMarketing: percentSalesFromMarketing,
            profitMargin: profitMargin
        )
    }

    // MARK: - Profit Analysis

    /// Production cost excluding shipping (labor buffered + material buffered).
    /// Profit analysis needs shipping separated — the maker's shipping expense
    /// and the customer's shipping charge are distinct line items.
    static func productionCostExShipping(product: Product) -> Decimal {
        totalLaborCostBuffered(product: product) + totalMaterialCostBuffered(product: product)
    }

    /// Total fees charged by the platform on a single sale.
    ///
    /// Platform + processing % fees apply to the full customer payment
    /// (actualPrice + actualShippingCharge) — this matches real Etsy/Shopify/Amazon
    /// behavior where percentage fees are assessed on the total transaction.
    /// Marketing fees apply to the item price only (Etsy offsite ads do not
    /// apply to shipping). Fixed processing fee is per-transaction.
    static func totalSaleFees(
        actualPrice: Decimal,
        actualShippingCharge: Decimal,
        platformFee: Decimal,
        paymentProcessingFee: Decimal,
        paymentProcessingFixed: Decimal,
        marketingFee: Decimal,
        percentSalesFromMarketing: Decimal
    ) -> Decimal {
        let grossRevenue = actualPrice + actualShippingCharge
        let transactionalFees = grossRevenue * (platformFee + paymentProcessingFee)
        let marketing = effectiveMarketingRate(
            marketingFee: marketingFee,
            percentSalesFromMarketing: percentSalesFromMarketing
        )
        let marketingCost = actualPrice * marketing
        return transactionalFees + marketingCost + paymentProcessingFixed
    }

    /// Actual profit per sale after all platform fees and costs.
    ///
    /// Formula:
    ///   grossRevenue = actualPrice + actualShippingCharge
    ///   profit = grossRevenue - totalSaleFees - productionCostExShipping - shippingCost
    static func actualProfit(
        actualPrice: Decimal,
        actualShippingCharge: Decimal,
        productionCostExShipping: Decimal,
        shippingCost: Decimal,
        platformFee: Decimal,
        paymentProcessingFee: Decimal,
        paymentProcessingFixed: Decimal,
        marketingFee: Decimal,
        percentSalesFromMarketing: Decimal
    ) -> Decimal {
        let grossRevenue = actualPrice + actualShippingCharge
        let fees = totalSaleFees(
            actualPrice: actualPrice,
            actualShippingCharge: actualShippingCharge,
            platformFee: platformFee,
            paymentProcessingFee: paymentProcessingFee,
            paymentProcessingFixed: paymentProcessingFixed,
            marketingFee: marketingFee,
            percentSalesFromMarketing: percentSalesFromMarketing
        )
        return grossRevenue - fees - productionCostExShipping - shippingCost
    }

    /// Actual profit for a product, computing production cost and shipping from the model.
    static func actualProfit(
        product: Product,
        actualPrice: Decimal,
        actualShippingCharge: Decimal,
        platformFee: Decimal,
        paymentProcessingFee: Decimal,
        paymentProcessingFixed: Decimal,
        marketingFee: Decimal,
        percentSalesFromMarketing: Decimal
    ) -> Decimal {
        actualProfit(
            actualPrice: actualPrice,
            actualShippingCharge: actualShippingCharge,
            productionCostExShipping: productionCostExShipping(product: product),
            shippingCost: product.shippingCost,
            platformFee: platformFee,
            paymentProcessingFee: paymentProcessingFee,
            paymentProcessingFixed: paymentProcessingFixed,
            marketingFee: marketingFee,
            percentSalesFromMarketing: percentSalesFromMarketing
        )
    }

    /// Actual profit margin as a fraction of gross revenue.
    /// Returns nil if gross revenue is zero (avoids division by zero).
    static func actualProfitMargin(
        profit: Decimal,
        actualPrice: Decimal,
        actualShippingCharge: Decimal
    ) -> Decimal? {
        let grossRevenue = actualPrice + actualShippingCharge
        guard grossRevenue > 0 else { return nil }
        return profit / grossRevenue
    }

    // MARK: - Take-Home Metrics

    /// Total labor hours for a product across all work steps.
    static func totalLaborHours(product: Product) -> Decimal {
        product.productWorkSteps.reduce(Decimal.zero) { sum, link in
            sum + laborHoursPerProduct(link: link)
        }
    }

    /// Take-home amount per labor hour (solo-maker effective hourly wage).
    /// Returns nil when total labor hours is zero.
    static func takeHomePerHour(
        actualProfit: Decimal,
        laborCostBuffered: Decimal,
        totalLaborHours: Decimal
    ) -> Decimal? {
        guard totalLaborHours > 0 else { return nil }
        return (actualProfit + laborCostBuffered) / totalLaborHours
    }

    /// Take-home per hour using model data.
    static func takeHomePerHour(
        product: Product,
        actualProfit: Decimal
    ) -> Decimal? {
        let hours = totalLaborHours(product: product)
        let laborCost = totalLaborCostBuffered(product: product)
        return takeHomePerHour(actualProfit: actualProfit, laborCostBuffered: laborCost, totalLaborHours: hours)
    }

    // MARK: - Time Formatting

    /// Formats a Decimal hours value to a readable string.
    /// Shows up to 4 decimal places, strips trailing zeros, keeps minimum 2.
    /// Examples: 0.002777… → "0.0028", 1.5 → "1.50", 0.25 → "0.25"
    static func formatHours(_ value: Decimal) -> String {
        let double = NSDecimalNumber(decimal: value).doubleValue
        let full = String(format: "%.4f", double)
        // Strip trailing zeros but keep at least 2 decimal places
        let parts = full.split(separator: ".", maxSplits: 1)
        guard parts.count == 2 else { return full }
        let intPart = parts[0]
        var decPart = String(parts[1])
        while decPart.count > 2 && decPart.hasSuffix("0") {
            decPart.removeLast()
        }
        return "\(intPart).\(decPart)"
    }

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

    /// Formats seconds into stopwatch display: "MM:SS.t" or "H:MM:SS.t"
    static func formatStopwatchTime(_ seconds: TimeInterval) -> String {
        let total = max(0, seconds)
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        let s = Int(total) % 60
        let tenths = Int((total - Double(Int(total))) * 10)
        if h > 0 {
            return String(format: "%d:%02d:%02d.%d", h, m, s, tenths)
        }
        return String(format: "%02d:%02d.%d", m, s, tenths)
    }

    /// Formats Decimal hours to a human-readable "Xh Ym" string.
    /// Drops seconds — batch-level display doesn't need second-level precision.
    /// Examples: 0.5 → "0h 30m", 4.75 → "4h 45m", 0 → "0h 0m"
    static func formatHoursReadable(_ hours: Decimal) -> String {
        let totalSeconds = Int(NSDecimalNumber(decimal: hours).doubleValue * 3600)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        return "\(h)h \(m)m"
    }

    // MARK: - Batch Forecasting (Epic 5)

    // MARK: Batch Labor

    /// Labor hours for a single step across the entire batch.
    static func batchStepHours(link: ProductWorkStep, batchSize: Int) -> Decimal {
        laborHoursPerProduct(link: link) * Decimal(batchSize)
    }

    /// Raw-value overload.
    static func batchStepHours(laborHoursPerProduct: Decimal, batchSize: Int) -> Decimal {
        laborHoursPerProduct * Decimal(batchSize)
    }

    /// Total labor hours for all steps across the entire batch.
    static func batchLaborHours(product: Product, batchSize: Int) -> Decimal {
        totalLaborHours(product: product) * Decimal(batchSize)
    }

    /// Raw-value overload.
    static func batchLaborHours(totalLaborHoursPerUnit: Decimal, batchSize: Int) -> Decimal {
        totalLaborHoursPerUnit * Decimal(batchSize)
    }

    // MARK: Batch Materials

    /// Units of a single material needed for the entire batch.
    static func batchMaterialUnits(link: ProductMaterial, batchSize: Int) -> Decimal {
        link.unitsRequiredPerProduct * Decimal(batchSize)
    }

    /// Raw-value overload.
    static func batchMaterialUnits(unitsRequiredPerProduct: Decimal, batchSize: Int) -> Decimal {
        unitsRequiredPerProduct * Decimal(batchSize)
    }

    /// Cost of a single material line across the entire batch (before buffer).
    static func batchMaterialLineCost(link: ProductMaterial, batchSize: Int) -> Decimal {
        materialLineCost(link: link) * Decimal(batchSize)
    }

    /// Raw-value overload.
    static func batchMaterialLineCost(materialLineCostPerUnit: Decimal, batchSize: Int) -> Decimal {
        materialLineCostPerUnit * Decimal(batchSize)
    }

    /// Number of bulk purchases required to fulfill a batch's material needs.
    /// Uses ceiling division. Returns (0, 0, 0) if bulkQuantity is zero or negative.
    static func bulkPurchasesNeeded(
        unitsNeeded: Decimal,
        bulkQuantity: Decimal
    ) -> (purchases: Int, totalBulkUnits: Decimal, leftover: Decimal) {
        guard bulkQuantity > 0 else { return (0, 0, 0) }
        let ratio = unitsNeeded / bulkQuantity
        let purchases = Int(NSDecimalNumber(decimal: ratio).doubleValue.rounded(.up))
        let totalBulkUnits = Decimal(purchases) * bulkQuantity
        let leftover = totalBulkUnits - unitsNeeded
        return (purchases, totalBulkUnits, leftover)
    }

    /// Total cost to purchase enough bulk units for the batch.
    static func batchPurchaseCost(purchases: Int, bulkCost: Decimal) -> Decimal {
        Decimal(purchases) * bulkCost
    }

    // MARK: Batch Cost Summary

    /// Total production cost for the entire batch (with buffers and shipping).
    static func batchProductionCost(product: Product, batchSize: Int) -> Decimal {
        totalProductionCost(product: product) * Decimal(batchSize)
    }

    /// Raw-value overload.
    static func batchProductionCost(totalProductionCostPerUnit: Decimal, batchSize: Int) -> Decimal {
        totalProductionCostPerUnit * Decimal(batchSize)
    }

    /// Cost per unit within a batch. Returns 0 if batchSize is zero.
    static func batchCostPerUnit(batchProductionCost: Decimal, batchSize: Int) -> Decimal {
        guard batchSize > 0 else { return 0 }
        return batchProductionCost / Decimal(batchSize)
    }

    // MARK: Batch Revenue

    /// Gross revenue for the entire batch.
    static func batchRevenue(
        actualPrice: Decimal,
        actualShippingCharge: Decimal,
        batchSize: Int
    ) -> Decimal {
        (actualPrice + actualShippingCharge) * Decimal(batchSize)
    }

    /// Total platform fees for the entire batch.
    /// Each sale is an independent transaction — fixed fees apply per sale.
    static func batchTotalFees(
        actualPrice: Decimal,
        actualShippingCharge: Decimal,
        platformFee: Decimal,
        paymentProcessingFee: Decimal,
        paymentProcessingFixed: Decimal,
        marketingFee: Decimal,
        percentSalesFromMarketing: Decimal,
        batchSize: Int
    ) -> Decimal {
        totalSaleFees(
            actualPrice: actualPrice,
            actualShippingCharge: actualShippingCharge,
            platformFee: platformFee,
            paymentProcessingFee: paymentProcessingFee,
            paymentProcessingFixed: paymentProcessingFixed,
            marketingFee: marketingFee,
            percentSalesFromMarketing: percentSalesFromMarketing
        ) * Decimal(batchSize)
    }

    /// Total profit for the entire batch.
    static func batchProfit(
        actualPrice: Decimal,
        actualShippingCharge: Decimal,
        productionCostExShipping: Decimal,
        shippingCost: Decimal,
        platformFee: Decimal,
        paymentProcessingFee: Decimal,
        paymentProcessingFixed: Decimal,
        marketingFee: Decimal,
        percentSalesFromMarketing: Decimal,
        batchSize: Int
    ) -> Decimal {
        actualProfit(
            actualPrice: actualPrice,
            actualShippingCharge: actualShippingCharge,
            productionCostExShipping: productionCostExShipping,
            shippingCost: shippingCost,
            platformFee: platformFee,
            paymentProcessingFee: paymentProcessingFee,
            paymentProcessingFixed: paymentProcessingFixed,
            marketingFee: marketingFee,
            percentSalesFromMarketing: percentSalesFromMarketing
        ) * Decimal(batchSize)
    }

    // MARK: - Batch Cost Breakdowns

    /// Buffered labor cost scaled to a batch.
    static func batchLaborCostBuffered(product: Product, batchSize: Int) -> Decimal {
        totalLaborCostBuffered(product: product) * Decimal(batchSize)
    }

    /// Buffered material cost scaled to a batch.
    static func batchMaterialCostBuffered(product: Product, batchSize: Int) -> Decimal {
        totalMaterialCostBuffered(product: product) * Decimal(batchSize)
    }

    /// Shipping cost scaled to a batch.
    static func batchShippingCost(product: Product, batchSize: Int) -> Decimal {
        product.shippingCost * Decimal(batchSize)
    }

    /// Production cost excluding shipping, scaled to a batch.
    static func batchProductionCostExShipping(product: Product, batchSize: Int) -> Decimal {
        productionCostExShipping(product: product) * Decimal(batchSize)
    }

    /// Batch earnings = batch profit + batch labor cost (solo-maker take-home).
    static func batchEarnings(batchProfit: Decimal, batchLaborCostBuffered: Decimal) -> Decimal {
        batchProfit + batchLaborCostBuffered
    }

    /// Earnings per unit in a batch. Returns nil if batch size is zero.
    static func batchEarningsPerUnit(batchEarnings: Decimal, batchSize: Int) -> Decimal? {
        guard batchSize > 0 else { return nil }
        return batchEarnings / Decimal(batchSize)
    }

    // MARK: - Fee Breakdown Amounts

    /// Dollar amount of platform fee on a transaction.
    static func platformFeeAmount(grossRevenue: Decimal, platformFee: Decimal) -> Decimal {
        grossRevenue * platformFee
    }

    /// Dollar amount of payment processing fee on a transaction.
    static func processingFeeAmount(grossRevenue: Decimal, processingFee: Decimal, processingFixed: Decimal) -> Decimal {
        grossRevenue * processingFee + processingFixed
    }

    /// Dollar amount of marketing fee on a transaction.
    static func marketingFeeAmount(actualPrice: Decimal, effectiveMarketingRate: Decimal) -> Decimal {
        actualPrice * effectiveMarketingRate
    }

    /// Total percentage fees (platform + processing + effective marketing).
    static func totalPercentFees(platformFee: Decimal, paymentProcessingFee: Decimal, effectiveMarketing: Decimal) -> Decimal {
        platformFee + paymentProcessingFee + effectiveMarketing
    }

    // MARK: - Cost Breakdown Fractions

    /// Cost breakdown as fractions for stacked bar visualization.
    /// Returns (0, 0, 0) when total production cost is zero.
    static func costBreakdownFractions(
        laborCostBuffered: Decimal,
        materialCostBuffered: Decimal,
        shippingCost: Decimal
    ) -> (labor: Double, material: Double, shipping: Double) {
        let total = laborCostBuffered + materialCostBuffered + shippingCost
        guard total > 0 else { return (0, 0, 0) }
        let toDouble: (Decimal) -> Double = { NSDecimalNumber(decimal: $0 / total).doubleValue }
        return (toDouble(laborCostBuffered), toDouble(materialCostBuffered), toDouble(shippingCost))
    }

    // MARK: - Portfolio Metrics (Epic 6)

    /// Precomputed metrics snapshot for a single product, used by the portfolio
    /// comparison view. Avoids repeated CostingEngine calls when rendering
    /// multiple products side-by-side.
    struct ProductSnapshot {
        let product: Product
        let productionCost: Decimal
        let laborCostBuffered: Decimal
        let materialCostBuffered: Decimal
        let shippingCost: Decimal
        let totalLaborHours: Decimal
        /// Solo-maker hero metric: actualProfit + laborCostBuffered.
        let earnings: Decimal
        /// actualProfit (revenue - fees - costs).
        let profit: Decimal
        /// actualProfitMargin (nil when no revenue).
        let profitMargin: Decimal?
        /// takeHomePerHour (nil when no labor hours).
        let hourlyRate: Decimal?
        /// Whether a ProductPricing with actualPrice > 0 exists for the selected platform.
        let hasPricing: Bool
        /// Display label for the platform (e.g. "General", "Etsy").
        let platformLabel: String
    }

    /// Returns the ProductPricing record for a specific platform, if it exists
    /// and has actualPrice > 0. Returns nil otherwise.
    ///
    /// Portfolio uses this to evaluate all products against the same platform,
    /// ensuring apples-to-apples comparison.
    static func portfolioPricing(
        for product: Product,
        platform: PlatformType
    ) -> ProductPricing? {
        product.productPricings.first(where: {
            $0.platformType == platform && $0.actualPrice > 0
        })
    }

    /// Builds a full metrics snapshot for one product using the specified
    /// platform's pricing. Cost fields are always populated; profit fields
    /// are zeroed/nil when no pricing exists for the platform.
    static func productSnapshot(
        product: Product,
        platform: PlatformType
    ) -> ProductSnapshot {
        // Single pass over productWorkSteps — accumulate both cost and hours
        var rawLaborCost: Decimal = 0
        var totalLaborHrs: Decimal = 0
        for link in product.productWorkSteps {
            guard link.workStep != nil else { continue }
            let hours = laborHoursPerProduct(link: link)
            totalLaborHrs += hours
            rawLaborCost += hours * link.laborRate
        }

        // Single pass over productMaterials
        var rawMaterialCost: Decimal = 0
        for link in product.productMaterials {
            guard let mat = link.material else { continue }
            rawMaterialCost += materialUnitCost(bulkCost: mat.bulkCost, bulkQuantity: mat.bulkQuantity) * link.unitsRequiredPerProduct
        }

        // Derive buffered costs and production cost from cached values
        let laborBuffered = rawLaborCost * (1 + product.laborBuffer)
        let materialBuffered = rawMaterialCost * (1 + product.materialBuffer)
        let shipping = product.shippingCost
        let prodCostExShipping = laborBuffered + materialBuffered
        let prodCost = prodCostExShipping + shipping

        guard let pricing = portfolioPricing(for: product, platform: platform) else {
            return ProductSnapshot(
                product: product,
                productionCost: prodCost,
                laborCostBuffered: laborBuffered,
                materialCostBuffered: materialBuffered,
                shippingCost: shipping,
                totalLaborHours: totalLaborHrs,
                earnings: 0,
                profit: 0,
                profitMargin: nil,
                hourlyRate: nil,
                hasPricing: false,
                platformLabel: platform.rawValue
            )
        }

        let fees = resolvedFees(
            platformType: platform,
            userPlatformFee: pricing.platformFee,
            userPaymentProcessingFee: pricing.paymentProcessingFee,
            userMarketingFee: pricing.marketingFee,
            userPercentSalesFromMarketing: pricing.percentSalesFromMarketing,
            userProfitMargin: pricing.profitMargin
        )

        // Use raw-value overload to avoid re-traversing relationships
        let profit = actualProfit(
            actualPrice: pricing.actualPrice,
            actualShippingCharge: pricing.actualShippingCharge,
            productionCostExShipping: prodCostExShipping,
            shippingCost: shipping,
            platformFee: fees.platformFee,
            paymentProcessingFee: fees.paymentProcessingFee,
            paymentProcessingFixed: fees.paymentProcessingFixed,
            marketingFee: fees.marketingFee,
            percentSalesFromMarketing: fees.percentSalesFromMarketing
        )

        let margin = actualProfitMargin(
            profit: profit,
            actualPrice: pricing.actualPrice,
            actualShippingCharge: pricing.actualShippingCharge
        )

        let hourly = takeHomePerHour(
            actualProfit: profit,
            laborCostBuffered: laborBuffered,
            totalLaborHours: totalLaborHrs
        )

        return ProductSnapshot(
            product: product,
            productionCost: prodCost,
            laborCostBuffered: laborBuffered,
            materialCostBuffered: materialBuffered,
            shippingCost: shipping,
            totalLaborHours: totalLaborHrs,
            earnings: profit + laborBuffered,
            profit: profit,
            profitMargin: margin,
            hourlyRate: hourly,
            hasPricing: true,
            platformLabel: platform.rawValue
        )
    }

    /// Builds snapshots for all products using the specified platform's pricing.
    /// Returns unsorted — the view layer handles sort order.
    static func portfolioSnapshots(
        products: [Product],
        platform: PlatformType
    ) -> [ProductSnapshot] {
        products.map { productSnapshot(product: $0, platform: platform) }
    }

    /// Portfolio-level averages computed only across products that have pricing.
    ///
    /// Returns nil for avgProfitMargin when no priced products have revenue.
    /// Returns nil for avgHourlyRate when no priced products have labor hours.
    static func portfolioAverages(
        snapshots: [ProductSnapshot]
    ) -> (avgEarnings: Decimal, avgProfitMargin: Decimal?,
          avgHourlyRate: Decimal?, pricedCount: Int, totalCount: Int) {
        let totalCount = snapshots.count
        let priced = snapshots.filter { $0.hasPricing }
        let pricedCount = priced.count

        guard pricedCount > 0 else {
            return (0, nil, nil, 0, totalCount)
        }

        let avgEarnings = priced.reduce(Decimal.zero) { $0 + $1.earnings }
            / Decimal(pricedCount)

        let margins = priced.compactMap { $0.profitMargin }
        let avgMargin: Decimal? = margins.isEmpty ? nil
            : margins.reduce(Decimal.zero, +) / Decimal(margins.count)

        let rates = priced.compactMap { $0.hourlyRate }
        let avgRate: Decimal? = rates.isEmpty ? nil
            : rates.reduce(Decimal.zero, +) / Decimal(rates.count)

        return (avgEarnings, avgMargin, avgRate, pricedCount, totalCount)
    }

    // MARK: - Unit & Accessibility Formatting

    /// Cached formatter for unit quantities — strips trailing zeros, max 4 decimals.
    private static let unitsFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 4
        f.numberStyle = .decimal
        return f
    }()

    /// Formats a Decimal quantity, stripping unnecessary trailing zeros.
    static func formatUnits(_ value: Decimal) -> String {
        unitsFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    /// Formats per-unit labor hours in human-readable minutes/hours.
    /// Under 1 hour: "23m/ea". 1 hour+: "1h 15m/ea".
    static func formatPerUnitTime(hours: Decimal) -> String {
        let totalMinutes = Int(NSDecimalNumber(decimal: hours).doubleValue * 60)
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)h \(totalMinutes % 60)m/ea"
        }
        return "\(totalMinutes)m/ea"
    }

    /// VoiceOver-friendly time description: "5 minutes, 30 seconds".
    static func accessibleTimeDescription(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return "\(h) hour\(h == 1 ? "" : "s"), \(m) minute\(m == 1 ? "" : "s"), \(s) second\(s == 1 ? "" : "s")"
        } else if m > 0 {
            return "\(m) minute\(m == 1 ? "" : "s"), \(s) second\(s == 1 ? "" : "s")"
        } else {
            return "\(s) second\(s == 1 ? "" : "s")"
        }
    }

    /// Returns "+" for positive values, "" for zero or negative.
    /// Negative values already display "-" from NumberFormatter.
    static func signedProfitPrefix(_ value: Decimal) -> String {
        value > 0 ? "+" : ""
    }
}
