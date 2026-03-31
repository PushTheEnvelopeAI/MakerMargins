// PlatformFeeProfile.swift
// MakerMargins
//
// Stores user-configurable default pricing values per platform type.
// One record per PlatformType, managed in Settings. Created lazily on first access.
// Platform-imposed fees (transaction %, fixed $, marketing rate) are hardcoded
// constants on PlatformType — only user-configurable values are persisted here.

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
    /// Which platform this defaults record covers. One per PlatformType.
    var platformType: PlatformType

    /// Default transaction fee percentage (fraction, e.g. 0.05 = 5%).
    /// Only used by the General tab — specific platforms have locked values.
    var transactionFeePercentage: Decimal

    /// Default fixed fee per sale ($).
    /// Only used by the General tab — specific platforms have locked values.
    var fixedFeePerSale: Decimal

    /// Default marketing fee rate (fraction, e.g. 0.15 = 15%).
    /// Editable on General, Shopify, Amazon. Etsy locks this at 15% (offsite ads).
    var marketingFeeRate: Decimal

    /// Default fraction of sales that come from marketing (fraction, e.g. 0.20 = 20%).
    /// Editable on all platforms.
    var percentSalesFromMarketing: Decimal

    /// Default target profit margin (fraction, e.g. 0.30 = 30%).
    var profitMargin: Decimal

    init(
        platformType: PlatformType = .general,
        transactionFeePercentage: Decimal = 0,
        fixedFeePerSale: Decimal = 0,
        marketingFeeRate: Decimal = 0,
        percentSalesFromMarketing: Decimal = 0,
        profitMargin: Decimal = 0.30
    ) {
        self.platformType = platformType
        self.transactionFeePercentage = transactionFeePercentage
        self.fixedFeePerSale = fixedFeePerSale
        self.marketingFeeRate = marketingFeeRate
        self.percentSalesFromMarketing = percentSalesFromMarketing
        self.profitMargin = profitMargin
    }
}

// MARK: - Platform Fee Constants & Editability

extension PlatformType {

    // MARK: Locked Fee Constants

    /// Total percentage-based transaction fee locked for this platform (fraction).
    /// Returns nil for General (user-entered).
    var lockedTransactionFee: Decimal? {
        switch self {
        case .general:  return nil
        case .etsy:     return Decimal(string: "0.095")!   // 6.5% transaction + 3% payment processing
        case .shopify:  return Decimal(string: "0.029")!   // 2.9% payment processing
        case .amazon:   return Decimal(string: "0.15")!    // 15% referral fee
        }
    }

    /// Fixed dollar fee per sale locked for this platform.
    /// Returns nil for General (user-entered).
    var lockedFixedFee: Decimal? {
        switch self {
        case .general:  return nil
        case .etsy:     return Decimal(string: "0.45")!    // $0.20 listing + $0.25 processing
        case .shopify:  return Decimal(string: "0.30")!    // $0.30 per-transaction
        case .amazon:   return Decimal(0)                  // No fixed per-sale fee for Handmade
        }
    }

    /// Marketing/advertising fee rate locked for this platform (fraction).
    /// Returns nil when user-editable.
    var lockedMarketingFeeRate: Decimal? {
        switch self {
        case .etsy:     return Decimal(string: "0.15")!    // 15% offsite ads rate
        case .general, .shopify, .amazon: return nil
        }
    }

    // MARK: Editability Flags

    /// Whether the transaction fee percentage is user-editable for this platform.
    var isTransactionFeeEditable: Bool { self == .general }

    /// Whether the fixed fee per sale is user-editable for this platform.
    var isFixedFeeEditable: Bool { self == .general }

    /// Whether the marketing fee rate is user-editable for this platform.
    var isMarketingFeeRateEditable: Bool { self != .etsy }

    // MARK: Display Helpers

    /// Human-readable label for the marketing frequency field.
    var marketingFeeLabel: String {
        switch self {
        case .etsy: return "% Sales from Offsite Ads"
        default:    return "% Sales from Marketing"
        }
    }

    /// Human-readable locked fee descriptions for display as read-only rows.
    var lockedFeeDescriptions: [(label: String, value: String)] {
        switch self {
        case .general:
            return []
        case .etsy:
            return [
                ("Transaction Fee", "6.5%"),
                ("Payment Processing", "3% + $0.25"),
                ("Listing Fee", "$0.20"),
                ("Offsite Ads Rate", "15%"),
            ]
        case .shopify:
            return [
                ("Payment Processing", "2.9% + $0.30"),
            ]
        case .amazon:
            return [
                ("Referral Fee", "15%"),
            ]
        }
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
