// EntitlementManager.swift
// MakerMargins
//
// Wraps RevenueCat to manage Pro entitlements (annual subscription + lifetime purchase).
// @Observable, injected via @Environment. Follows the existing manager pattern.
//
// Trial state is delegated to RevenueCat — their backend tracks trial start and
// expiration accurately across devices. No manual UserDefaults tracking needed.
//
// Cross-platform: when Android/web ship, the same RevenueCat project handles
// Google Play Billing / Stripe entitlements with the same isPro check.

import Foundation
import RevenueCat
import SwiftUI

@Observable
@MainActor
final class EntitlementManager {

    // MARK: - Published State

    private(set) var isPro: Bool = false
    private(set) var isInTrial: Bool = false
    private(set) var trialDaysRemaining: Int = 0
    private(set) var activeEntitlement: EntitlementState = .none
    private(set) var availablePackages: [Package] = []
    private(set) var isLoading: Bool = true

    enum EntitlementState: Equatable {
        case trial
        case annual
        case lifetime
        case none
    }

    // MARK: - Initialization

    init() {
        let apiKey = Secrets.revenueCatAPIKey
        guard !apiKey.isEmpty else {
            AppLogger.storeKit.info("RevenueCat skipped: no API key configured")
            isLoading = false
            return
        }

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)

        Task { await loadOfferings() }
        Task { await observeCustomerInfo() }

        AppLogger.storeKit.info("RevenueCat initialized")
    }

    // MARK: - Public Methods

    /// Purchase a package (annual or lifetime). Throws on failure.
    func purchase(package: Package) async throws {
        AppLogger.storeKit.info("Purchase attempted: \(package.identifier, privacy: .public)")
        let result = try await Purchases.shared.purchase(package: package)
        updateState(from: result.customerInfo)
        AppLogger.storeKit.info("Purchase succeeded: \(package.identifier, privacy: .public)")
    }

    /// Restore purchases from a previous device or reinstall.
    func restorePurchases() async throws {
        AppLogger.storeKit.info("Restore purchases requested")
        let customerInfo = try await Purchases.shared.restorePurchases()
        updateState(from: customerInfo)
        AppLogger.storeKit.info("Restore complete. isPro: \(self.isPro, privacy: .public)")
    }

    /// Refresh entitlement state from RevenueCat (e.g. on app foreground).
    func refreshCustomerInfo() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateState(from: customerInfo)
        } catch {
            AppLogger.storeKit.error("Failed to refresh customer info: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Check whether the user is eligible for the intro offer (free trial) on a given package.
    /// Used to dynamically show/hide the "14-day free trial" badge on the paywall.
    func introOfferEligible(for package: Package) async -> Bool {
        do {
            let eligibility = try await Purchases.shared.checkTrialOrIntroDiscountEligibility(packages: [package])
            return eligibility[package.identifier]?.status == .eligible
        } catch {
            AppLogger.storeKit.error("Intro offer eligibility check failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Private

    private func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            if let current = offerings.current {
                availablePackages = current.availablePackages
                AppLogger.storeKit.info("Loaded \(current.availablePackages.count, privacy: .public) packages")
            }
        } catch {
            AppLogger.storeKit.error("Failed to load offerings: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }

    private func observeCustomerInfo() async {
        for await customerInfo in Purchases.shared.customerInfoStream {
            updateState(from: customerInfo)
        }
    }

    private func updateState(from customerInfo: CustomerInfo) {
        let proEntitlement = customerInfo.entitlements["pro"]
        let isActive = proEntitlement?.isActive == true

        isPro = isActive
        isInTrial = proEntitlement?.periodType == .trial

        // Compute trial days remaining
        if isInTrial, let expirationDate = proEntitlement?.expirationDate {
            let days = Calendar.current.dateComponents([.day], from: .now, to: expirationDate).day ?? 0
            trialDaysRemaining = max(0, days)
        } else {
            trialDaysRemaining = 0
        }

        // Determine active entitlement type
        if !isActive {
            activeEntitlement = .none
        } else if isInTrial {
            activeEntitlement = .trial
        } else if proEntitlement?.expirationDate == nil {
            // Non-consumable (lifetime) has no expiration
            activeEntitlement = .lifetime
        } else {
            activeEntitlement = .annual
        }

        AppLogger.storeKit.info("Entitlement updated: \(String(describing: self.activeEntitlement), privacy: .public), isPro: \(self.isPro, privacy: .public)")
    }
}

// MARK: - Environment Key

struct EntitlementManagerKey: EnvironmentKey {
    @MainActor static let defaultValue = EntitlementManager()
}

extension EnvironmentValues {
    var entitlementManager: EntitlementManager {
        get { self[EntitlementManagerKey.self] }
        set { self[EntitlementManagerKey.self] = newValue }
    }
}
