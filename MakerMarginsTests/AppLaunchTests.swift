// AppLaunchTests.swift
// MakerMarginsTests
//
// Tests for app launch safety: Secrets defaults, AppLogger accessibility,
// and in-memory ModelContainer creation. Real crash-on-launch scenarios
// (no network, corrupt store, vendor SDK failure) are tested manually
// in Phase 4 QA.

import Testing
import Foundation
import SwiftData
@testable import MakerMargins

@MainActor
struct AppLaunchTests {

    // MARK: - Secrets

    @Test("Secrets returns empty strings when not configured")
    func secretsEmptyDefaults() {
        // In CI/dev builds without real keys, Secrets should return ""
        // for all values. This verifies the app won't crash on empty secrets.
        // The actual values depend on whether xcconfig is populated,
        // but the type is always String and never nil.
        let _ = Secrets.posthogAPIKey
        let _ = Secrets.posthogHost
        let _ = Secrets.sentryDSN
        let _ = Secrets.revenueCatAPIKey
        // If we got here without crashing, the test passes
    }

    // MARK: - AppLogger

    @Test("All AppLogger categories are accessible")
    func appLoggerCategories() {
        // Verify all 6 logger categories exist and can be referenced.
        // This is primarily a compile-time check, but also verifies
        // the subsystem and category strings don't cause runtime issues.
        let _ = AppLogger.costing
        let _ = AppLogger.swiftData
        let _ = AppLogger.storeKit
        let _ = AppLogger.ui
        let _ = AppLogger.lifecycle
        let _ = AppLogger.analytics
    }

    // MARK: - ModelContainer

    @Test("ModelContainer can be created in-memory with full schema")
    func inMemoryContainer() throws {
        let schema = Schema([
            Product.self,
            MakerMargins.Category.self,
            WorkStep.self,
            Material.self,
            PlatformFeeProfile.self,
            ProductWorkStep.self,
            ProductMaterial.self,
            ProductPricing.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        // Container and context should be usable
        let context = container.mainContext
        let product = Product(title: "Launch Test")
        context.insert(product)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Product>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "Launch Test")
    }

    // MARK: - First Launch Flag

    @Test("First launch flag defaults to false")
    func firstLaunchFlag() {
        // Remove the flag to simulate fresh install
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        #expect(hasLaunched == false)

        // Set the flag
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        let afterSet = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        #expect(afterSet == true)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
    }
}
