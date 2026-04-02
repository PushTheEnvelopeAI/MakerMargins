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

    /// Platform fee percentage override (fraction, e.g. 0.05 = 5%).
    /// Only editable on General — specific platforms use locked constants.
    var platformFee: Decimal

    /// Payment processing fee percentage override (fraction, e.g. 0.03 = 3%).
    /// Only editable on General — specific platforms use locked constants.
    var paymentProcessingFee: Decimal

    /// Marketing fee rate override (fraction, e.g. 0.15 = 15%).
    /// Editable on General, Shopify, Amazon. Etsy locks this at 15%.
    var marketingFee: Decimal

    /// Fraction of sales that come from marketing/ads (fraction, e.g. 0.20 = 20%).
    /// Editable on all platforms.
    var percentSalesFromMarketing: Decimal

    /// Target profit margin (fraction, e.g. 0.30 = 30%).
    var profitMargin: Decimal

    /// What the user actually charges on this platform (e.g. $49.99).
    /// Default: 0 (not yet set — profit analysis hidden until user enters a price).
    var actualPrice: Decimal

    /// What the customer pays for shipping on this platform.
    /// Default: 0 (free shipping). Platform-specific — makers may charge $0 on Amazon,
    /// a fixed rate on Etsy, or pass through the full cost on Shopify.
    var actualShippingCharge: Decimal

    init(
        product: Product? = nil,
        platformType: PlatformType = .general,
        platformFee: Decimal = 0,
        paymentProcessingFee: Decimal = 0,
        marketingFee: Decimal = 0,
        percentSalesFromMarketing: Decimal = 0,
        profitMargin: Decimal = 0.30,
        actualPrice: Decimal = 0,
        actualShippingCharge: Decimal = 0
    ) {
        self.product = product
        self.platformType = platformType
        self.platformFee = platformFee
        self.paymentProcessingFee = paymentProcessingFee
        self.marketingFee = marketingFee
        self.percentSalesFromMarketing = percentSalesFromMarketing
        self.profitMargin = profitMargin
        self.actualPrice = actualPrice
        self.actualShippingCharge = actualShippingCharge
    }
}
