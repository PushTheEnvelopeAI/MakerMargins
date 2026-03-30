// Epic3Tests.swift
// MakerMarginsTests
//
// E2E regression tests for Epic 3: Material Ledger & Costing.
// Covers Material CRUD, ProductMaterial join model behaviour,
// shared material semantics, cascade deletes, CostingEngine material
// calculations, per-section buffer formula, and product duplication.
//
// Each test creates its own isolated in-memory ModelContainer so tests
// never share state. Uses Swift Testing (import Testing, @Test, #expect).

import Testing
import Foundation
import SwiftData
@testable import MakerMargins

@MainActor
struct Epic3Tests {

    // MARK: - Helpers

    /// Returns a fresh in-memory ModelContainer with the full app schema.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Product.self,
            Category.self,
            WorkStep.self,
            Material.self,
            PlatformFeeProfile.self,
            ProductWorkStep.self,
            ProductMaterial.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Material & ProductMaterial CRUD

    @Test("Create a Material with all fields, persist, and fetch back")
    func createAndFetchMaterial() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let material = Material(
            title: "Walnut Lumber",
            summary: "Kiln-dried 4/4 walnut",
            image: imageData,
            link: "https://example.com/walnut",
            bulkCost: Decimal(string: "45.00")!,
            bulkQuantity: Decimal(string: "10")!,
            unitName: "board-foot",
            defaultUnitsPerProduct: Decimal(string: "3")!
        )
        ctx.insert(material)
        try ctx.save()

        let results = try ctx.fetch(FetchDescriptor<Material>())
        #expect(results.count == 1)
        #expect(results[0].title == "Walnut Lumber")
        #expect(results[0].summary == "Kiln-dried 4/4 walnut")
        #expect(results[0].image == imageData)
        #expect(results[0].link == "https://example.com/walnut")
        #expect(results[0].bulkCost == Decimal(string: "45.00")!)
        #expect(results[0].bulkQuantity == Decimal(string: "10")!)
        #expect(results[0].unitName == "board-foot")
        #expect(results[0].defaultUnitsPerProduct == Decimal(string: "3")!)
    }

    @Test("Create a ProductMaterial association and verify sortOrder")
    func createProductMaterialAssociation() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Cutting Board")
        let material = Material(title: "Maple Lumber")
        let link = ProductMaterial(product: product, material: material, sortOrder: 2)

        product.productMaterials.append(link)
        material.productMaterials.append(link)

        ctx.insert(product)
        ctx.insert(material)
        ctx.insert(link)
        try ctx.save()

        let products = try ctx.fetch(FetchDescriptor<Product>())
        #expect(products[0].productMaterials.count == 1)
        #expect(products[0].productMaterials[0].sortOrder == 2)
        #expect(products[0].productMaterials[0].material?.title == "Maple Lumber")
    }

    @Test("Shared material linked to two products reflects edits in both")
    func sharedMaterialAcrossProducts() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let productA = Product(title: "Product A")
        let productB = Product(title: "Product B")
        let material = Material(title: "Shared Sandpaper", bulkCost: Decimal(string: "10.00")!)

        let linkA = ProductMaterial(product: productA, material: material, sortOrder: 0)
        let linkB = ProductMaterial(product: productB, material: material, sortOrder: 0)

        productA.productMaterials.append(linkA)
        productB.productMaterials.append(linkB)
        material.productMaterials.append(linkA)
        material.productMaterials.append(linkB)

        ctx.insert(productA)
        ctx.insert(productB)
        ctx.insert(material)
        ctx.insert(linkA)
        ctx.insert(linkB)
        try ctx.save()

        #expect(material.productMaterials.count == 2)

        // Edit the material — should be visible from both products
        material.bulkCost = Decimal(string: "15.00")!
        try ctx.save()

        let matFromA = productA.productMaterials[0].material
        let matFromB = productB.productMaterials[0].material
        #expect(matFromA?.bulkCost == Decimal(string: "15.00")!)
        #expect(matFromB?.bulkCost == Decimal(string: "15.00")!)
    }

    @Test("Reordering materials updates sortOrder values correctly")
    func reorderMaterialsUpdatesSortOrder() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Reorder Product")
        let matA = Material(title: "Material A")
        let matB = Material(title: "Material B")
        let matC = Material(title: "Material C")

        let linkA = ProductMaterial(product: product, material: matA, sortOrder: 0)
        let linkB = ProductMaterial(product: product, material: matB, sortOrder: 1)
        let linkC = ProductMaterial(product: product, material: matC, sortOrder: 2)

        product.productMaterials.append(linkA)
        product.productMaterials.append(linkB)
        product.productMaterials.append(linkC)
        matA.productMaterials.append(linkA)
        matB.productMaterials.append(linkB)
        matC.productMaterials.append(linkC)

        ctx.insert(product)
        ctx.insert(matA)
        ctx.insert(matB)
        ctx.insert(matC)
        ctx.insert(linkA)
        ctx.insert(linkB)
        ctx.insert(linkC)
        try ctx.save()

        // Simulate moving Material C (index 2) to position 0 (before Material A)
        // New order: C, A, B
        var links = product.productMaterials.sorted { $0.sortOrder < $1.sortOrder }
        links.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        for (index, link) in links.enumerated() {
            link.sortOrder = index
        }
        try ctx.save()

        let sorted = product.productMaterials.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted[0].material?.title == "Material C")
        #expect(sorted[0].sortOrder == 0)
        #expect(sorted[1].material?.title == "Material A")
        #expect(sorted[1].sortOrder == 1)
        #expect(sorted[2].material?.title == "Material B")
        #expect(sorted[2].sortOrder == 2)
    }

    @Test("Deleting a product removes associations but preserves the shared Material")
    func deleteProductPreservesSharedMaterial() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Doomed Product")
        let material = Material(title: "Survivor Material")
        let link = ProductMaterial(product: product, material: material, sortOrder: 0)

        product.productMaterials.append(link)
        material.productMaterials.append(link)

        ctx.insert(product)
        ctx.insert(material)
        ctx.insert(link)
        try ctx.save()

        ctx.delete(product)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<Product>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<ProductMaterial>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Material>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<Material>())[0].title == "Survivor Material")
    }

    @Test("Deleting a Material cascades to its ProductMaterial associations")
    func deleteMaterialCascadesToAssociations() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Keeper Product")
        let material = Material(title: "Doomed Material")
        let link = ProductMaterial(product: product, material: material, sortOrder: 0)

        product.productMaterials.append(link)
        material.productMaterials.append(link)

        ctx.insert(product)
        ctx.insert(material)
        ctx.insert(link)
        try ctx.save()

        ctx.delete(material)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<Material>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<ProductMaterial>()).isEmpty)
        // Product survives
        let products = try ctx.fetch(FetchDescriptor<Product>())
        #expect(products.count == 1)
        #expect(products[0].title == "Keeper Product")
    }

    // MARK: - CostingEngine Material Calculations

    @Test("materialUnitCost returns correct value for known inputs")
    func materialUnitCostKnownValues() {
        // $20 / 10 units = $2 per unit
        let result = CostingEngine.materialUnitCost(bulkCost: 20, bulkQuantity: 10)
        #expect(result == Decimal(string: "2")!)
    }

    @Test("materialUnitCost returns zero when bulkQuantity is zero")
    func materialUnitCostZeroQuantityGuard() {
        let result = CostingEngine.materialUnitCost(bulkCost: 20, bulkQuantity: 0)
        #expect(result == 0)
    }

    @Test("materialLineCost returns correct value for known inputs")
    func materialLineCostKnownValues() {
        // $20 / 10 units = $2/unit × 3 units/product = $6
        let result = CostingEngine.materialLineCost(
            bulkCost: 20,
            bulkQuantity: 10,
            unitsRequiredPerProduct: 3
        )
        #expect(result == Decimal(string: "6")!)
    }

    @Test("totalMaterialCost sums across multiple materials linked to a product")
    func totalMaterialCostMultipleMaterials() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Multi-material Product")

        // Material A: $20 / 10 units, 3 per product → $6
        let matA = Material(
            title: "Material A",
            bulkCost: Decimal(string: "20")!,
            bulkQuantity: Decimal(string: "10")!,
            defaultUnitsPerProduct: Decimal(string: "3")!
        )
        // Material B: $50 / 5 units, 2 per product → $20
        let matB = Material(
            title: "Material B",
            bulkCost: Decimal(string: "50")!,
            bulkQuantity: Decimal(string: "5")!,
            defaultUnitsPerProduct: Decimal(string: "2")!
        )

        let linkA = ProductMaterial(product: product, material: matA, sortOrder: 0, unitsRequiredPerProduct: matA.defaultUnitsPerProduct)
        let linkB = ProductMaterial(product: product, material: matB, sortOrder: 1, unitsRequiredPerProduct: matB.defaultUnitsPerProduct)

        product.productMaterials.append(linkA)
        product.productMaterials.append(linkB)
        matA.productMaterials.append(linkA)
        matB.productMaterials.append(linkB)

        ctx.insert(product)
        ctx.insert(matA)
        ctx.insert(matB)
        ctx.insert(linkA)
        ctx.insert(linkB)
        try ctx.save()

        let total = CostingEngine.totalMaterialCost(product: product)
        #expect(total == Decimal(string: "26")!)
    }

    @Test("totalProductionCost applies per-section buffers correctly with labor and material")
    func totalProductionCostWithPerSectionBuffers() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Product: shipping $5, materialBuffer 10%, laborBuffer 5%
        let product = Product(
            title: "Buffered Product",
            shippingCost: Decimal(string: "5")!,
            materialBuffer: Decimal(string: "0.10")!,
            laborBuffer: Decimal(string: "0.05")!
        )

        // One step: 3600s, 1 batch, 1 unit/product, $20/hr → $20 labor
        let step = WorkStep(
            title: "Only Step",
            laborRate: 20,
            recordedTime: 3600,
            batchUnitsCompleted: 1,
            defaultUnitsPerProduct: 1
        )
        let stepLink = ProductWorkStep(product: product, workStep: step, sortOrder: 0)
        product.productWorkSteps.append(stepLink)
        step.productWorkSteps.append(stepLink)

        // One material: $20 / 10 units, 3 per product → $6 material
        let material = Material(
            title: "Only Material",
            bulkCost: Decimal(string: "20")!,
            bulkQuantity: Decimal(string: "10")!,
            defaultUnitsPerProduct: Decimal(string: "3")!
        )
        let matLink = ProductMaterial(product: product, material: material, sortOrder: 0, unitsRequiredPerProduct: material.defaultUnitsPerProduct)
        product.productMaterials.append(matLink)
        material.productMaterials.append(matLink)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(stepLink)
        ctx.insert(material)
        ctx.insert(matLink)
        try ctx.save()

        // Per-section buffers:
        // $20 labor × (1 + 0.05) = $21
        // $6 material × (1 + 0.10) = $6.60
        // + $5 shipping
        // Total = $32.60
        let total = CostingEngine.totalProductionCost(product: product)
        #expect(total == Decimal(string: "32.6")!)
    }

    // MARK: - Product Duplication

    @Test("Product duplication re-links shared materials via new ProductMaterial associations")
    func duplicateProductRelinksSharedMaterials() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let source = Product(title: "Original Board")
        let material = Material(
            title: "Oak Lumber",
            bulkCost: Decimal(string: "30.00")!,
            bulkQuantity: Decimal(string: "5")!,
            unitName: "board-foot",
            defaultUnitsPerProduct: Decimal(string: "2")!
        )
        let matLink = ProductMaterial(product: source, material: material, sortOrder: 0)
        source.productMaterials.append(matLink)
        material.productMaterials.append(matLink)

        ctx.insert(source)
        ctx.insert(material)
        ctx.insert(matLink)
        try ctx.save()

        // --- Duplicate (mirrors ProductListView.duplicateProduct logic) ---
        let copy = Product(
            title: "\(source.title) (Copy)",
            summary: source.summary,
            shippingCost: source.shippingCost,
            materialBuffer: source.materialBuffer,
            laborBuffer: source.laborBuffer
        )
        ctx.insert(copy)

        for srcLink in source.productMaterials {
            guard let mat = srcLink.material else { continue }
            let newLink = ProductMaterial(product: copy, material: mat, sortOrder: srcLink.sortOrder)
            ctx.insert(newLink)
            copy.productMaterials.append(newLink)
            mat.productMaterials.append(newLink)
        }
        try ctx.save()

        // --- Assertions ---
        let products = try ctx.fetch(FetchDescriptor<Product>())
        #expect(products.count == 2)

        let copied = products.first { $0.title == "Original Board (Copy)" }!

        // Material re-linked (shared, same instance)
        #expect(copied.productMaterials.count == 1)
        #expect(copied.productMaterials[0].material?.title == "Oak Lumber")
        #expect(copied.productMaterials[0].sortOrder == 0)

        // Only 1 Material total — shared, now linked to 2 products
        let materials = try ctx.fetch(FetchDescriptor<Material>())
        #expect(materials.count == 1)
        #expect(materials[0].productMaterials.count == 2)
    }
}
