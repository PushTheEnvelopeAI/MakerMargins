// CurrencyFormatter.swift
// MakerMargins
//
// Shared formatter for displaying monetary Decimal values.
// Respects the user's currency setting (USD default, EUR option).
// All views must route monetary display through this formatter — never format inline.
//
// Injected once at the app root and accessed via @Environment(\.currencyFormatter).

import Foundation
import Observation
import SwiftUI

// MARK: - Currency

enum Currency: String, CaseIterable, Identifiable {
    case usd = "USD"
    case eur = "EUR"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usd: return "USD ($)"
        case .eur: return "EUR (€)"
        }
    }
}

// MARK: - CurrencyFormatter

@Observable
final class CurrencyFormatter {
    var selected: Currency = .usd {
        didSet {
            if oldValue != selected {
                numberFormatter.currencyCode = selected.rawValue
            }
        }
    }

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Currency.usd.rawValue
        return f
    }()

    /// Format a Decimal monetary value using the currently selected currency.
    /// Never casts Decimal to Double — uses NSDecimalNumber for lossless conversion.
    func format(_ value: Decimal) -> String {
        numberFormatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

// MARK: - Environment

private struct CurrencyFormatterKey: EnvironmentKey {
    static let defaultValue = CurrencyFormatter()
}

extension EnvironmentValues {
    var currencyFormatter: CurrencyFormatter {
        get { self[CurrencyFormatterKey.self] }
        set { self[CurrencyFormatterKey.self] = newValue }
    }
}
