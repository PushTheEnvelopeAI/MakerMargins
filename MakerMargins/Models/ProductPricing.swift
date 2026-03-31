// ProductPricing.swift
// MakerMargins
//
// Per-product per-platform pricing overrides.
// Stores user-configurable pricing values for a specific Product on a specific platform.
// Created lazily when the user first visits a platform tab in the pricing calculator,
// initialized from PlatformFeeProfile defaults.
// Up to 4 per product (one per PlatformType).

import Foundation
import SwiftData

@Model
final class ProductPricing {
    /// The product this pricing belongs to.
    var product: Product?

    /// Which platform these pricing overrides are for.
    var platformType: PlatformType

    /// Transaction fee percentage override (fraction, e.g. 0.05 = 5%).
    /// Used by General tab only — specific platforms use locked constants.
    var transactionFeePercentage: Decimal

    /// Fixed fee per sale override ($).
    /// Used by General tab only — specific platforms use locked constants.
    var fixedFeePerSale: Decimal

    /// Marketing fee rate override (fraction, e.g. 0.15 = 15%).
    /// Editable on General, Shopify, Amazon. Etsy locks this at 15%.
    var marketingFeeRate: Decimal

    /// Fraction of sales that come from marketing (fraction, e.g. 0.20 = 20%).
    /// Editable on all platforms.
    var percentSalesFromMarketing: Decimal

    /// Target profit margin (fraction, e.g. 0.30 = 30%).
    var profitMargin: Decimal

    init(
        product: Product? = nil,
        platformType: PlatformType = .general,
        transactionFeePercentage: Decimal = 0,
        fixedFeePerSale: Decimal = 0,
        marketingFeeRate: Decimal = 0,
        percentSalesFromMarketing: Decimal = 0,
        profitMargin: Decimal = 0.30
    ) {
        self.product = product
        self.platformType = platformType
        self.transactionFeePercentage = transactionFeePercentage
        self.fixedFeePerSale = fixedFeePerSale
        self.marketingFeeRate = marketingFeeRate
        self.percentSalesFromMarketing = percentSalesFromMarketing
        self.profitMargin = profitMargin
    }
}
