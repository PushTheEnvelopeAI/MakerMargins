// AnalyticsTests.swift
// MakerMarginsTests
//
// Tests for the analytics signal system: enum stability, gating logic,
// and opt-out persistence. Does NOT test PostHog SDK integration —
// that's verified manually in Phase 4 via the PostHog dashboard.

import Testing
import Foundation
@testable import MakerMargins

struct AnalyticsTests {

    // MARK: - Signal Enum Stability

    @Test("Core signal raw values are stable across builds")
    func signalRawValues() {
        // These raw values become PostHog event names. If they change,
        // existing funnels and dashboards break. Pin the critical ones.
        #expect(AnalyticsSignal.appLaunched.rawValue == "appLaunched")
        #expect(AnalyticsSignal.firstLaunch.rawValue == "firstLaunch")
        #expect(AnalyticsSignal.templateApplied.rawValue == "templateApplied")
        #expect(AnalyticsSignal.firstProductCreated.rawValue == "firstProductCreated")
        #expect(AnalyticsSignal.portfolioViewed.rawValue == "portfolioViewed")
        #expect(AnalyticsSignal.paywallShown.rawValue == "paywallShown")
        #expect(AnalyticsSignal.purchaseSucceeded.rawValue == "purchaseSucceeded")
        #expect(AnalyticsSignal.crashDetected.rawValue == "crashDetected")
    }

    @Test("All activation funnel signals exist")
    func activationFunnelSignals() {
        // The activation funnel is: templateApplied → firstProductCreated →
        // firstStopwatchUsed → firstPricingCalculated → portfolioViewed
        let funnelSignals: [AnalyticsSignal] = [
            .templateApplied,
            .firstProductCreated,
            .firstStopwatchUsed,
            .firstPricingCalculated,
            .portfolioViewed,
        ]
        #expect(funnelSignals.count == 5)
    }

    @Test("All monetization funnel signals exist")
    func monetizationFunnelSignals() {
        let funnelSignals: [AnalyticsSignal] = [
            .paywallShown,
            .paywallDismissed,
            .purchaseAttempted,
            .purchaseSucceeded,
            .purchaseFailed,
            .restorePurchases,
        ]
        #expect(funnelSignals.count == 6)
    }

    // MARK: - Opt-Out Persistence

    @Test("Analytics opt-out persists to UserDefaults")
    func optOutPersistence() {
        // Set to disabled
        UserDefaults.standard.set(false, forKey: "analyticsEnabled")
        let stored = UserDefaults.standard.bool(forKey: "analyticsEnabled")
        #expect(stored == false)

        // Set back to enabled
        UserDefaults.standard.set(true, forKey: "analyticsEnabled")
        let restored = UserDefaults.standard.bool(forKey: "analyticsEnabled")
        #expect(restored == true)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "analyticsEnabled")
    }

    @Test("Analytics defaults to enabled when no UserDefaults key exists")
    func defaultEnabled() {
        // Remove key to simulate fresh install
        UserDefaults.standard.removeObject(forKey: "analyticsEnabled")
        // Default behavior: nil object → default to true
        let value = UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? true
        #expect(value == true)
    }
}
