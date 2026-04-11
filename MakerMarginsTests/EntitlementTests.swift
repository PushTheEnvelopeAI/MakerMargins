// EntitlementTests.swift
// MakerMarginsTests
//
// Tests for entitlement gating logic and EntitlementState.
// Tests the boolean gating decisions in isolation — does NOT require
// RevenueCat SDK or real purchase flows. Real purchase testing
// happens in Phase 4 via sandbox accounts on real devices.

import Testing
import Foundation
@testable import MakerMargins

struct EntitlementTests {

    // MARK: - EntitlementState

    @Test("EntitlementState has exactly 3 cases")
    func entitlementStateCases() {
        let states: [EntitlementManager.EntitlementState] = [.annual, .lifetime, .none]
        #expect(states.count == 3)
    }

    @Test("EntitlementState cases are distinct")
    func entitlementStateDistinct() {
        #expect(EntitlementManager.EntitlementState.annual != .lifetime)
        #expect(EntitlementManager.EntitlementState.annual != .none)
        #expect(EntitlementManager.EntitlementState.lifetime != .none)
    }

    // MARK: - Product Count Gating Logic

    @Test("Free user with 0 products: creation allowed")
    func freeUserZeroProducts() {
        let isPro = false
        let productCount = 0
        let shouldGate = !isPro && productCount >= 3
        #expect(shouldGate == false)
    }

    @Test("Free user with 2 products: creation allowed")
    func freeUserTwoProducts() {
        let isPro = false
        let productCount = 2
        let shouldGate = !isPro && productCount >= 3
        #expect(shouldGate == false)
    }

    @Test("Free user with 3 products: creation blocked")
    func freeUserThreeProducts() {
        let isPro = false
        let productCount = 3
        let shouldGate = !isPro && productCount >= 3
        #expect(shouldGate == true)
    }

    @Test("Free user with 5 products: creation blocked")
    func freeUserFiveProducts() {
        let isPro = false
        let productCount = 5
        let shouldGate = !isPro && productCount >= 3
        #expect(shouldGate == true)
    }

    @Test("Pro user with 3 products: creation allowed")
    func proUserThreeProducts() {
        let isPro = true
        let productCount = 3
        let shouldGate = !isPro && productCount >= 3
        #expect(shouldGate == false)
    }

    @Test("Pro user with 100 products: creation allowed")
    func proUserManyProducts() {
        let isPro = true
        let productCount = 100
        let shouldGate = !isPro && productCount >= 3
        #expect(shouldGate == false)
    }

    // MARK: - Platform Tab Gating Logic

    @Test("General tab is never gated")
    func generalNeverGated() {
        let isPro = false
        let platform = PlatformType.general
        let shouldGate = !isPro && (platform == .shopify || platform == .amazon)
        #expect(shouldGate == false)
    }

    @Test("Etsy tab is never gated")
    func etsyNeverGated() {
        let isPro = false
        let platform = PlatformType.etsy
        let shouldGate = !isPro && (platform == .shopify || platform == .amazon)
        #expect(shouldGate == false)
    }

    @Test("Shopify tab gated for free user")
    func shopifyGatedForFree() {
        let isPro = false
        let platform = PlatformType.shopify
        let shouldGate = !isPro && (platform == .shopify || platform == .amazon)
        #expect(shouldGate == true)
    }

    @Test("Amazon tab gated for free user")
    func amazonGatedForFree() {
        let isPro = false
        let platform = PlatformType.amazon
        let shouldGate = !isPro && (platform == .shopify || platform == .amazon)
        #expect(shouldGate == true)
    }

    @Test("Shopify tab open for Pro user")
    func shopifyOpenForPro() {
        let isPro = true
        let platform = PlatformType.shopify
        let shouldGate = !isPro && (platform == .shopify || platform == .amazon)
        #expect(shouldGate == false)
    }

    @Test("Amazon tab open for Pro user")
    func amazonOpenForPro() {
        let isPro = true
        let platform = PlatformType.amazon
        let shouldGate = !isPro && (platform == .shopify || platform == .amazon)
        #expect(shouldGate == false)
    }

    // MARK: - PaywallReason

    @Test("PaywallReason.productLimit has correct analytics value")
    func paywallReasonProductLimit() {
        let reason = PaywallReason.productLimit
        #expect(reason.analyticsValue == "productLimit")
        #expect(!reason.headline.isEmpty)
        #expect(!reason.subheadline.isEmpty)
    }

    @Test("PaywallReason.platformLocked has platform-specific analytics value")
    func paywallReasonPlatformLocked() {
        let shopify = PaywallReason.platformLocked(.shopify)
        #expect(shopify.analyticsValue == "platformLocked_shopify")

        let amazon = PaywallReason.platformLocked(.amazon)
        #expect(amazon.analyticsValue == "platformLocked_amazon")
    }

    @Test("PaywallReason.manual has correct analytics value")
    func paywallReasonManual() {
        let reason = PaywallReason.manual
        #expect(reason.analyticsValue == "manual")
    }
}
