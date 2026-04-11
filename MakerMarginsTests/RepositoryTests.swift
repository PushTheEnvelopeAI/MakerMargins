// RepositoryTests.swift
// MakerMarginsTests
//
// Tests for the writes-only repository layer introduced in Epic 7.
// Verifies create, delete, duplicate, touch, and join management operations.

import Testing
import Foundation
import SwiftData
@testable import MakerMargins

@MainActor
struct RepositoryTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Product.self, Category.self, WorkStep.self, Material.self,
            PlatformFeeProfile.self, ProductWorkStep.self, ProductMaterial.self, ProductPricing.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - ProductRepository

    @Test("ProductRepository.create sets timestamps")
    func productCreateSetsTimestamps() throws {
        let container = try makeContainer()
        let repo = SwiftDataProductRepository(context: container.mainContext)
        let before = Date.now
        let product = repo.create(title: "Cutting Board")
        let after = Date.now

        #expect(product.title == "Cutting Board")
        #expect(product.createdAt >= before)
        #expect(product.createdAt <= after)
        #expect(product.updatedAt >= before)
    }

    @Test("ProductRepository.touch advances updatedAt but not createdAt")
    func productTouchAdvancesUpdatedAt() throws {
        let container = try makeContainer()
        let repo = SwiftDataProductRepository(context: container.mainContext)
        let product = repo.create(title: "Board")
        let originalCreatedAt = product.createdAt
        let originalUpdatedAt = product.updatedAt

        // Small delay to ensure time advances
        Thread.sleep(forTimeInterval: 0.01)
        repo.touch(product)

        #expect(product.createdAt == originalCreatedAt)
        #expect(product.updatedAt > originalUpdatedAt)
    }

    @Test("ProductRepository.delete removes the product")
    func productDelete() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = SwiftDataProductRepository(context: context)
        let product = repo.create(title: "Board")
        try context.save()

        repo.delete(product)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Product>())
        #expect(remaining.isEmpty)
    }

    @Test("ProductRepository.duplicate creates a new entity with fresh timestamps")
    func productDuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = SwiftDataProductRepository(context: context)
        let original = repo.create(title: "Board")
        original.shippingCost = 5
        try context.save()

        Thread.sleep(forTimeInterval: 0.01)
        let copy = repo.duplicate(original)

        #expect(copy.title == "Board Copy")
        #expect(copy.shippingCost == 5)
        #expect(copy.createdAt > original.createdAt)

        let allProducts = try context.fetch(FetchDescriptor<Product>())
        #expect(allProducts.count == 2)
    }

    @Test("ProductRepository.duplicate deep copies work steps")
    func productDuplicateDeepCopiesSteps() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let productRepo = SwiftDataProductRepository(context: context)
        let stepRepo = SwiftDataWorkStepRepository(context: context)

        let product = productRepo.create(title: "Board")
        let step = stepRepo.create(title: "Sand")
        stepRepo.addToProduct(step, product: product, laborRate: 25, unitsRequired: 1, sortOrder: 0)
        try context.save()

        let copy = productRepo.duplicate(product)
        try context.save()

        #expect(copy.productWorkSteps.count == 1)
        #expect(copy.productWorkSteps.first?.workStep?.title == "Sand")
        // Join is a new entity, but the shared WorkStep is the same
        #expect(copy.productWorkSteps.first?.workStep === step)
    }

    // MARK: - WorkStepRepository

    @Test("WorkStepRepository.create sets timestamps")
    func workStepCreateSetsTimestamps() throws {
        let container = try makeContainer()
        let repo = SwiftDataWorkStepRepository(context: container.mainContext)
        let step = repo.create(title: "Sand")

        #expect(step.title == "Sand")
        #expect(step.createdAt <= .now)
        #expect(step.updatedAt <= .now)
    }

    @Test("WorkStepRepository.addToProduct creates properly configured join")
    func workStepAddToProduct() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let productRepo = SwiftDataProductRepository(context: context)
        let stepRepo = SwiftDataWorkStepRepository(context: context)

        let product = productRepo.create(title: "Board")
        let step = stepRepo.create(title: "Sand")
        let link = stepRepo.addToProduct(step, product: product, laborRate: 25, unitsRequired: 2, sortOrder: 0)

        #expect(link.product === product)
        #expect(link.workStep === step)
        #expect(link.laborRate == 25)
        #expect(link.unitsRequiredPerProduct == 2)
        #expect(link.sortOrder == 0)
    }

    @Test("WorkStepRepository.removeFromProduct deletes join without deleting step")
    func workStepRemoveFromProduct() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let productRepo = SwiftDataProductRepository(context: context)
        let stepRepo = SwiftDataWorkStepRepository(context: context)

        let product = productRepo.create(title: "Board")
        let step = stepRepo.create(title: "Sand")
        let link = stepRepo.addToProduct(step, product: product, laborRate: 25, unitsRequired: 1, sortOrder: 0)
        try context.save()

        stepRepo.removeFromProduct(link)
        try context.save()

        // Step survives
        let steps = try context.fetch(FetchDescriptor<WorkStep>())
        #expect(steps.count == 1)

        // Join is gone
        let joins = try context.fetch(FetchDescriptor<ProductWorkStep>())
        #expect(joins.isEmpty)
    }

    @Test("WorkStepRepository.reorder updates sortOrder values")
    func workStepReorder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let productRepo = SwiftDataProductRepository(context: context)
        let stepRepo = SwiftDataWorkStepRepository(context: context)

        let product = productRepo.create(title: "Board")
        let step1 = stepRepo.create(title: "Cut")
        let step2 = stepRepo.create(title: "Sand")
        let link1 = stepRepo.addToProduct(step1, product: product, laborRate: 25, unitsRequired: 1, sortOrder: 0)
        let link2 = stepRepo.addToProduct(step2, product: product, laborRate: 25, unitsRequired: 1, sortOrder: 1)

        // Reverse order
        stepRepo.reorder([link2, link1])

        #expect(link2.sortOrder == 0)
        #expect(link1.sortOrder == 1)
    }

    // MARK: - MaterialRepository

    @Test("MaterialRepository.create sets timestamps")
    func materialCreateSetsTimestamps() throws {
        let container = try makeContainer()
        let repo = SwiftDataMaterialRepository(context: container.mainContext)
        let material = repo.create(title: "Walnut")

        #expect(material.title == "Walnut")
        #expect(material.createdAt <= .now)
    }

    @Test("MaterialRepository.addToProduct creates properly configured join")
    func materialAddToProduct() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let productRepo = SwiftDataProductRepository(context: context)
        let matRepo = SwiftDataMaterialRepository(context: context)

        let product = productRepo.create(title: "Board")
        let material = matRepo.create(title: "Walnut")
        let link = matRepo.addToProduct(material, product: product, unitsRequired: 3, sortOrder: 0)

        #expect(link.product === product)
        #expect(link.material === material)
        #expect(link.unitsRequiredPerProduct == 3)
    }

    @Test("MaterialRepository.removeFromProduct deletes join without deleting material")
    func materialRemoveFromProduct() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let productRepo = SwiftDataProductRepository(context: context)
        let matRepo = SwiftDataMaterialRepository(context: context)

        let product = productRepo.create(title: "Board")
        let material = matRepo.create(title: "Walnut")
        let link = matRepo.addToProduct(material, product: product, unitsRequired: 1, sortOrder: 0)
        try context.save()

        matRepo.removeFromProduct(link)
        try context.save()

        let materials = try context.fetch(FetchDescriptor<Material>())
        #expect(materials.count == 1)

        let joins = try context.fetch(FetchDescriptor<ProductMaterial>())
        #expect(joins.isEmpty)
    }

    // MARK: - CategoryRepository

    @Test("CategoryRepository.create sets timestamps")
    func categoryCreate() throws {
        let container = try makeContainer()
        let repo = SwiftDataCategoryRepository(context: container.mainContext)
        let category = repo.create(name: "Boards")

        #expect(category.name == "Boards")
        #expect(category.createdAt <= .now)
    }

    @Test("CategoryRepository.delete removes category")
    func categoryDelete() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = SwiftDataCategoryRepository(context: context)
        let category = repo.create(name: "Boards")
        try context.save()

        repo.delete(category)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Category>())
        #expect(remaining.isEmpty)
    }
}
