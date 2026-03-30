// Epic1Tests.swift
// MakerMarginsTests
//
// E2E regression tests for Epic 1: Product & Category Management.
// Covers CRUD operations for Product and Category, relationship behaviour,
// cascade deletes, and CurrencyFormatter correctness.
//
// Each test creates its own isolated in-memory ModelContainer so tests
// never share state. Uses Swift Testing (import Testing, @Test, #expect).

import Testing
import Foundation
import SwiftData
@testable import MakerMargins

@MainActor
struct Epic1Tests {

    // MARK: - Helpers

    /// Returns a fresh in-memory ModelContainer with the full app schema.
    /// Each test calls this independently so no state leaks between tests.
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

    // MARK: - Product CRUD

    @Test("Create a product and fetch it back via SwiftData")
    func createAndFetchProduct() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Walnut Cutting Board", summary: "12x18 end-grain board")
        ctx.insert(product)
        try ctx.save()

        let results = try ctx.fetch(FetchDescriptor<Product>())
        #expect(results.count == 1)
        #expect(results[0].title == "Walnut Cutting Board")
        #expect(results[0].summary == "12x18 end-grain board")
    }

    @Test("Edit a product and verify changes persist")
    func editProduct() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Oak Box", shippingCost: Decimal(string: "3.00")!)
        ctx.insert(product)
        try ctx.save()

        product.title = "Cherry Box"
        product.shippingCost = Decimal(string: "4.50")!
        try ctx.save()

        let results = try ctx.fetch(FetchDescriptor<Product>())
        #expect(results[0].title == "Cherry Box")
        #expect(results[0].shippingCost == Decimal(string: "4.50")!)
    }

    @Test("Delete a product and verify it is removed")
    func deleteProduct() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Maple Tray")
        ctx.insert(product)
        try ctx.save()

        ctx.delete(product)
        try ctx.save()

        let results = try ctx.fetch(FetchDescriptor<Product>())
        #expect(results.isEmpty)
    }

    // MARK: - Cascade Delete

    @Test("Deleting a product cascades to associations, but shared WorkSteps and Materials survive")
    func deleteProductCascadesToChildren() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Pine Shelf")
        let step = WorkStep(title: "Sand edges")
        let material = Material(title: "Sandpaper")

        // Link step to product via the join model (many-to-many)
        let stepLink = ProductWorkStep(product: product, workStep: step, sortOrder: 0)
        product.productWorkSteps.append(stepLink)
        step.productWorkSteps.append(stepLink)

        // Link material to product via the join model (many-to-many)
        let matLink = ProductMaterial(product: product, material: material, sortOrder: 0)
        product.productMaterials.append(matLink)
        material.productMaterials.append(matLink)

        ctx.insert(product)
        ctx.insert(step)
        ctx.insert(material)
        ctx.insert(stepLink)
        ctx.insert(matLink)
        try ctx.save()

        // Confirm everything exists before deleting
        #expect(try ctx.fetch(FetchDescriptor<WorkStep>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<Material>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<ProductWorkStep>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<ProductMaterial>()).count == 1)

        ctx.delete(product)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<Product>()).isEmpty)
        // ProductWorkStep association is cascade-deleted with the product
        #expect(try ctx.fetch(FetchDescriptor<ProductWorkStep>()).isEmpty)
        // ProductMaterial association is cascade-deleted with the product
        #expect(try ctx.fetch(FetchDescriptor<ProductMaterial>()).isEmpty)
        // WorkStep survives — it's a shared entity, not owned by the product
        #expect(try ctx.fetch(FetchDescriptor<WorkStep>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<WorkStep>())[0].title == "Sand edges")
        // Material survives — it's a shared entity, not owned by the product
        #expect(try ctx.fetch(FetchDescriptor<Material>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<Material>())[0].title == "Sandpaper")
    }

    // MARK: - Category CRUD

    @Test("Create a category and fetch it back")
    func createAndFetchCategory() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let category = Category(name: "Cutting Boards")
        ctx.insert(category)
        try ctx.save()

        let results = try ctx.fetch(FetchDescriptor<MakerMargins.Category>())
        #expect(results.count == 1)
        #expect(results[0].name == "Cutting Boards")
    }

    @Test("Assign a category to a product and verify the relationship")
    func assignCategoryToProduct() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let category = Category(name: "Jewelry")
        let product = Product(title: "Silver Ring")
        product.category = category

        ctx.insert(category)
        ctx.insert(product)
        try ctx.save()

        let fetchedProducts = try ctx.fetch(FetchDescriptor<Product>())
        #expect(fetchedProducts.count == 1)
        #expect(fetchedProducts[0].category?.name == "Jewelry")
    }

    @Test("Deleting a category nullifies the product's category, not the product")
    func deleteCategoryNullifiesProduct() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let category = Category(name: "Home Goods")
        let product = Product(title: "Candle Holder")
        product.category = category
        category.products.append(product)

        ctx.insert(category)
        ctx.insert(product)
        try ctx.save()

        ctx.delete(category)
        try ctx.save()

        // Product must still exist
        let products = try ctx.fetch(FetchDescriptor<Product>())
        #expect(products.count == 1)
        #expect(products[0].title == "Candle Holder")

        // Category reference must be nil (nullify delete rule)
        #expect(products[0].category == nil)

        // Category must be gone
        let categories = try ctx.fetch(FetchDescriptor<MakerMargins.Category>())
        #expect(categories.isEmpty)
    }

    // MARK: - Buffer Percentage Conversion

    @Test("Buffer percentage input converts to correct fraction on save")
    func bufferPercentageStoredAsFraction() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Simulate what ProductFormView.save() does:
        // user enters "10" in the material buffer field → divide by 100 before storing
        let enteredMaterialBuffer = Decimal(string: "10")!
        let enteredLaborBuffer = Decimal(string: "5")!

        let product = Product(
            title: "Test Product",
            materialBuffer: enteredMaterialBuffer / 100,
            laborBuffer: enteredLaborBuffer / 100
        )
        ctx.insert(product)
        try ctx.save()

        let results = try ctx.fetch(FetchDescriptor<Product>())
        #expect(results[0].materialBuffer == Decimal(string: "0.1")!)
        #expect(results[0].laborBuffer == Decimal(string: "0.05")!)
    }

    // MARK: - CurrencyFormatter

    @Test("CurrencyFormatter formats Decimal correctly for USD")
    func currencyFormatterUSD() {
        let formatter = CurrencyFormatter()
        formatter.selected = .usd

        let result = formatter.format(Decimal(string: "19.99")!)

        #expect(result.contains("19.99"))
        #expect(result.contains("$"))
    }

    @Test("CurrencyFormatter formats Decimal correctly for EUR")
    func currencyFormatterEUR() {
        let formatter = CurrencyFormatter()
        formatter.selected = .eur

        let result = formatter.format(Decimal(string: "19.99")!)

        #expect(result.contains("19.99"))
        // € symbol may appear as the code "EUR" depending on locale — check both
        let hasEuroSymbol = result.contains("€") || result.contains("EUR")
        #expect(hasEuroSymbol)
    }

    @Test("CurrencyFormatter switching currency updates output")
    func currencyFormatterSwitchUpdatesOutput() {
        let formatter = CurrencyFormatter()
        let value = Decimal(string: "10.00")!

        formatter.selected = .usd
        let usdResult = formatter.format(value)

        formatter.selected = .eur
        let eurResult = formatter.format(value)

        #expect(usdResult != eurResult)
    }

    @Test("CurrencyFormatter handles zero correctly")
    func currencyFormatterZero() {
        let formatter = CurrencyFormatter()
        formatter.selected = .usd

        let result = formatter.format(Decimal.zero)

        #expect(result.contains("0"))
        #expect(result.contains("$"))
    }

    // MARK: - Product Duplication

    @Test("Duplicating a product copies metadata, re-links shared steps and shared materials")
    func duplicateProductCopiesAllData() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let category = Category(name: "Boards")
        let source = Product(
            title: "Walnut Board",
            summary: "End-grain cutting board",
            shippingCost: Decimal(string: "8.50")!,
            materialBuffer: Decimal(string: "0.10")!,
            laborBuffer: Decimal(string: "0.05")!,
            category: category
        )

        // Add a shared WorkStep
        let step = WorkStep(title: "Sand edges", laborRate: 20, recordedTime: 1800)
        let stepLink = ProductWorkStep(product: source, workStep: step, sortOrder: 0)
        source.productWorkSteps.append(stepLink)
        step.productWorkSteps.append(stepLink)

        // Add a shared Material via join model
        let material = Material(
            title: "Walnut Lumber",
            bulkCost: Decimal(string: "45.00")!,
            bulkQuantity: Decimal(string: "10")!,
            unitName: "board-foot",
            defaultUnitsPerProduct: Decimal(string: "3")!
        )
        let matLink = ProductMaterial(product: source, material: material, sortOrder: 0)
        source.productMaterials.append(matLink)
        material.productMaterials.append(matLink)

        ctx.insert(category)
        ctx.insert(source)
        ctx.insert(step)
        ctx.insert(stepLink)
        ctx.insert(material)
        ctx.insert(matLink)
        try ctx.save()

        // --- Duplicate (mirrors ProductListView.duplicateProduct logic) ---
        let copy = Product(
            title: "\(source.title) (Copy)",
            summary: source.summary,
            image: source.image,
            shippingCost: source.shippingCost,
            materialBuffer: source.materialBuffer,
            laborBuffer: source.laborBuffer,
            category: source.category
        )
        ctx.insert(copy)

        for srcLink in source.productWorkSteps {
            guard let ws = srcLink.workStep else { continue }
            let newLink = ProductWorkStep(product: copy, workStep: ws, sortOrder: srcLink.sortOrder)
            ctx.insert(newLink)
            copy.productWorkSteps.append(newLink)
            ws.productWorkSteps.append(newLink)
        }

        // Re-link shared Materials via new ProductMaterial associations
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

        let copied = products.first { $0.title == "Walnut Board (Copy)" }!

        // Scalar metadata copied
        #expect(copied.summary == "End-grain cutting board")
        #expect(copied.shippingCost == Decimal(string: "8.50")!)
        #expect(copied.materialBuffer == Decimal(string: "0.10")!)
        #expect(copied.laborBuffer == Decimal(string: "0.05")!)
        #expect(copied.category?.name == "Boards")

        // Shared step re-linked (same WorkStep, new association)
        #expect(copied.productWorkSteps.count == 1)
        #expect(copied.productWorkSteps[0].workStep?.title == "Sand edges")
        #expect(copied.productWorkSteps[0].sortOrder == 0)

        // WorkStep is shared — still only 1 WorkStep total, now linked to 2 products
        let steps = try ctx.fetch(FetchDescriptor<WorkStep>())
        #expect(steps.count == 1)
        #expect(steps[0].productWorkSteps.count == 2)

        // Material re-linked (shared, same instance linked to both products)
        #expect(copied.productMaterials.count == 1)
        #expect(copied.productMaterials[0].material?.title == "Walnut Lumber")
        #expect(copied.productMaterials[0].material?.bulkCost == Decimal(string: "45.00")!)
        #expect(copied.productMaterials[0].sortOrder == 0)

        // Material is shared — still only 1 Material total, now linked to 2 products
        let materials = try ctx.fetch(FetchDescriptor<Material>())
        #expect(materials.count == 1)
        #expect(materials[0].productMaterials.count == 2)
    }
}
