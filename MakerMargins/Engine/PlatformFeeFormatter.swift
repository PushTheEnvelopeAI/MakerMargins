// PlatformFeeFormatter.swift
// MakerMargins
//
// Display formatting for platform-specific locked fees.
// Moved from PlatformFeeProfile model to keep models as pure data.

import SwiftUI

extension PlatformType {

    /// Formatted display string for locked platform fee, or nil if editable.
    func platformFeeDisplay() -> String? {
        guard let fee = lockedPlatformFee else { return nil }
        return PercentageFormat.toDisplay(fee) + "%"
    }

    /// Formatted display string for locked payment processing, or nil if editable.
    /// Combines percentage and fixed fee when both exist (e.g. "3% + $0.25").
    func paymentProcessingDisplay() -> String? {
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
    func marketingFeeDisplay() -> String? {
        guard let fee = lockedMarketingFee else { return nil }
        return PercentageFormat.toDisplay(fee) + "%"
    }
}
