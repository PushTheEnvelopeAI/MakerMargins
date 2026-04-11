// ModelIdentityTests.swift
// MakerMarginsTests
//
// Verifies the sync-readiness fields (remoteID, createdAt, updatedAt)
// behave correctly across all @Model classes.

import Testing
import Foundation
import SwiftData
@testable import MakerMargins

@MainActor
struct ModelIdentityTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Product.self, Category.self, WorkStep.self, Material.self,
            PlatformFeeProfile.self, ProductWorkStep.self, ProductMaterial.self, ProductPricing.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Product

    @Test("Product: createdAt and updatedAt are set on creation")
    func productTimestampsOnCreation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let before = Date.now
        let product = Product(title: "Test Board")
        context.insert(product)
        let after = Date.now

        #expect(product.createdAt >= before)
        #expect(product.createdAt <= after)
        #expect(product.updatedAt >= before)
        #expect(product.updatedAt <= after)
    }

    @Test("Product: remoteID is nil by default")
    func productRemoteIDNilByDefault() throws {
        let product = Product(title: "Test Board")
        #expect(product.remoteID == nil)
    }

    @Test("Product: remoteID is stable when set")
    func productRemoteIDStable() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let product = Product(title: "Test Board")
        let uuid = UUID()
        product.remoteID = uuid
        context.insert(product)
        try context.save()

        #expect(product.remoteID == uuid)
    }

    @Test("Product: createdAt does not change on mutation")
    func productCreatedAtImmutable() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let product = Product(title: "Test Board")
        context.insert(product)
        try context.save()
        let originalCreatedAt = product.createdAt

        // Simulate an update
        product.title = "Updated Board"
        product.updatedAt = .now
        try context.save()

        #expect(product.createdAt == originalCreatedAt)
    }

    // MARK: - Category

    @Test("Category: sync fields initialized correctly")
    func categorySyncFields() throws {
        let category = Category(name: "Cutting Boards")
        #expect(category.remoteID == nil)
        #expect(category.createdAt <= .now)
        #expect(category.updatedAt <= .now)
    }

    // MARK: - WorkStep

    @Test("WorkStep: sync fields initialized correctly")
    func workStepSyncFields() throws {
        let step = WorkStep(title: "Sand")
        #expect(step.remoteID == nil)
        #expect(step.createdAt <= .now)
        #expect(step.updatedAt <= .now)
    }

    // MARK: - Material

    @Test("Material: sync fields initialized correctly")
    func materialSyncFields() throws {
        let material = Material(title: "Walnut")
        #expect(material.remoteID == nil)
        #expect(material.createdAt <= .now)
        #expect(material.updatedAt <= .now)
    }

    // MARK: - Join Models

    @Test("ProductWorkStep: sync fields initialized correctly")
    func productWorkStepSyncFields() throws {
        let link = ProductWorkStep()
        #expect(link.remoteID == nil)
        #expect(link.createdAt <= .now)
        #expect(link.updatedAt <= .now)
    }

    @Test("ProductMaterial: sync fields initialized correctly")
    func productMaterialSyncFields() throws {
        let link = ProductMaterial()
        #expect(link.remoteID == nil)
        #expect(link.createdAt <= .now)
        #expect(link.updatedAt <= .now)
    }

    // MARK: - Pricing Models

    @Test("PlatformFeeProfile: sync fields initialized correctly")
    func platformFeeProfileSyncFields() throws {
        let profile = PlatformFeeProfile()
        #expect(profile.remoteID == nil)
        #expect(profile.createdAt <= .now)
        #expect(profile.updatedAt <= .now)
    }

    @Test("ProductPricing: sync fields initialized correctly")
    func productPricingSyncFields() throws {
        let pricing = ProductPricing()
        #expect(pricing.remoteID == nil)
        #expect(pricing.createdAt <= .now)
        #expect(pricing.updatedAt <= .now)
    }
}
