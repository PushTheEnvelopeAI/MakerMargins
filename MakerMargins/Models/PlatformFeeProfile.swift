// PlatformFeeProfile.swift
// MakerMargins
//
// Stores user-configurable default pricing values as a single universal record.
// Managed in Settings. Created lazily on first access.
// Platform-imposed fees are hardcoded constants on PlatformType — only
// user-configurable values are persisted here.

import Foundation
import SwiftData

// MARK: - Platform Type

enum PlatformType: String, Codable, CaseIterable {
    case general  = "General"
    case etsy     = "Etsy"
    case shopify  = "Shopify"
    case amazon   = "Amazon"
}

// MARK: - Model

@Model
final class PlatformFeeProfile {
    /// Default platform fee percentage (fraction, e.g. 0.05 = 5%).
    var platformFee: Decimal

    /// Default payment processing fee percentage (fraction, e.g. 0.03 = 3%).
    var paymentProcessingFee: Decimal

    /// Default marketing fee rate (fraction, e.g. 0.10 = 10%).
    var marketingFee: Decimal

    /// Default fraction of sales that come from marketing/ads (fraction, e.g. 0.20 = 20%).
    var percentSalesFromMarketing: Decimal

    /// Default target profit margin (fraction, e.g. 0.30 = 30%).
    var profitMargin: Decimal

    init(
        platformFee: Decimal = 0,
        paymentProcessingFee: Decimal = 0,
        marketingFee: Decimal = 0,
        percentSalesFromMarketing: Decimal = 0,
        profitMargin: Decimal = 0.30
    ) {
        self.platformFee = platformFee
        self.paymentProcessingFee = paymentProcessingFee
        self.marketingFee = marketingFee
        self.percentSalesFromMarketing = percentSalesFromMarketing
        self.profitMargin = profitMargin
    }
}

// MARK: - Platform Fee Constants & Editability

extension PlatformType {

    // MARK: Locked Fee Constants

    /// Platform's per-sale commission percentage (fraction). nil = user-editable.
    var lockedPlatformFee: Decimal? {
        switch self {
        case .general:  return nil
        case .etsy:     return Decimal(string: "0.065")!   // 6.5% transaction fee
        case .shopify:  return Decimal(0)                  // No per-sale commission
        case .amazon:   return Decimal(string: "0.15")!    // 15% referral fee
        }
    }

    /// Payment processing percentage (fraction). nil = user-editable.
    var lockedPaymentProcessingFee: Decimal? {
        switch self {
        case .general:  return nil
        case .etsy:     return Decimal(string: "0.03")!    // 3% payment processing
        case .shopify:  return Decimal(string: "0.029")!   // 2.9% Shopify Payments
        case .amazon:   return Decimal(0)                  // Bundled into referral fee
        }
    }

    /// Fixed dollar fee per transaction. Always a constant (never user-editable).
    var lockedPaymentProcessingFixed: Decimal {
        switch self {
        case .general:  return 0
        case .etsy:     return Decimal(string: "0.25")!    // $0.25 per transaction
        case .shopify:  return Decimal(string: "0.30")!    // $0.30 per transaction
        case .amazon:   return 0
        }
    }

    /// Marketing/advertising fee rate (fraction). nil = user-editable.
    var lockedMarketingFee: Decimal? {
        switch self {
        case .etsy:     return Decimal(string: "0.15")!    // 15% offsite ads rate
        case .general, .shopify, .amazon: return nil
        }
    }

    // MARK: Editability Flags

    var isPlatformFeeEditable: Bool { lockedPlatformFee == nil }
    var isPaymentProcessingFeeEditable: Bool { lockedPaymentProcessingFee == nil }
    var isMarketingFeeEditable: Bool { lockedMarketingFee == nil }

    // MARK: Display Helpers

    /// Formatted display string for locked platform fee, or nil if editable.
    var platformFeeDisplay: String? {
        guard let fee = lockedPlatformFee else { return nil }
        return PercentageFormat.toDisplay(fee) + "%"
    }

    /// Formatted display string for locked payment processing, or nil if editable.
    /// Combines percentage and fixed fee when both exist (e.g. "3% + $0.25").
    var paymentProcessingDisplay: String? {
        guard let fee = lockedPaymentProcessingFee else { return nil }
        let percentText = PercentageFormat.toDisplay(fee) + "%"
        let fixed = lockedPaymentProcessingFixed
        if fixed > 0 {
            let fixedStr = String(format: "%.2f", NSDecimalNumber(decimal: fixed).doubleValue)
            return "\(percentText) + $\(fixedStr)"
        }
        return percentText
    }

    /// Formatted display string for locked marketing fee, or nil if editable.
    var marketingFeeDisplay: String? {
        guard let fee = lockedMarketingFee else { return nil }
        return PercentageFormat.toDisplay(fee) + "%"
    }

    /// SF Symbol name for this platform.
    var iconName: String {
        switch self {
        case .general:  return "storefront"
        case .etsy:     return "bag"
        case .shopify:  return "cart"
        case .amazon:   return "shippingbox"
        }
    }
}
