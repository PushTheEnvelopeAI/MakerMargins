// PlatformFeeProfile.swift
// MakerMargins
//
// A selling platform's fee structure and profit margin goal.
// Global — not tied to any specific product. Used by CostingEngine to compute
// targetRetailPrice = totalProductionCost / (1 - (feePercentage + marginGoal))
//
// Multiple profiles of the same platform type are allowed (e.g. two Etsy shops
// with different margin goals), differentiated by the user-facing `name` field.

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
    /// User-facing label, e.g. "My Etsy Shop" or "Amazon FBA".
    var name: String

    /// Which selling platform this profile represents.
    var platformType: PlatformType

    /// Combined platform fee as a fraction. e.g. 0.065 = 6.5%.
    /// Includes all transaction and listing fees for the platform.
    var feePercentage: Decimal

    /// Target profit margin as a fraction. e.g. 0.30 = 30% margin goal.
    var marginGoal: Decimal

    init(
        name: String,
        platformType: PlatformType = .general,
        feePercentage: Decimal = 0,
        marginGoal: Decimal = 0.30
    ) {
        self.name = name
        self.platformType = platformType
        self.feePercentage = feePercentage
        self.marginGoal = marginGoal
    }
}
