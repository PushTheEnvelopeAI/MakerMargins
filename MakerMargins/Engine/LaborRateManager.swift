// LaborRateManager.swift
// MakerMargins
//
// Manages the user's default hourly labor rate.
// New WorkSteps are pre-filled with this rate; users can override per-step.
// Injected once at the app root and accessed via @Environment(\.laborRateManager).

import Foundation
import Observation
import SwiftUI

// MARK: - LaborRateManager

@MainActor
@Observable
final class LaborRateManager {

    /// Explicitly nonisolated so the type can be instantiated from any context
    /// (e.g. EnvironmentKey.defaultValue). All stored properties have inline
    /// defaults, so the body is empty.
    nonisolated init() {}

    /// Default hourly labor rate in the user's chosen currency.
    /// Pre-fills new WorkStep labor rates. Persisted to UserDefaults.
    var defaultRate: Decimal = {
        if let number = UserDefaults.standard.object(forKey: "defaultLaborRate") as? NSNumber {
            return number.decimalValue
        }
        return 15
    }() {
        didSet {
            if oldValue != defaultRate {
                UserDefaults.standard.set(NSDecimalNumber(decimal: defaultRate), forKey: "defaultLaborRate")
            }
        }
    }
}

// MARK: - Environment

private struct LaborRateManagerKey: EnvironmentKey {
    static let defaultValue = LaborRateManager()
}

extension EnvironmentValues {
    var laborRateManager: LaborRateManager {
        get { self[LaborRateManagerKey.self] }
        set { self[LaborRateManagerKey.self] = newValue }
    }
}
