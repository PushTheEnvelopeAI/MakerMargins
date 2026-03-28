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
import SwiftData
@testable import MakerMargins

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

        let product = Product(title: "Oak Box", shippingCost: Decimal("3.00")!)
        ctx.insert(product)
        try ctx.save()

        product.title = "Cherry Box"
        product.shippingCost = Decimal("4.50")!
        try ctx.save()

        let results = try ctx.fetch(FetchDescriptor<Product>())
        #expect(results[0].title == "Cherry Box")
        #expect(results[0].shippingCost == Decimal("4.50")!)
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

    @Test("Deleting a product cascades to its WorkSteps and Materials")
    func deleteProductCascadesToChildren() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let product = Product(title: "Pine Shelf")
        let step = WorkStep(title: "Sand edges")
        let material = Material(title: "Sandpaper")

        // Set relationships bidirectionally so SwiftData registers them before save
        step.product = product
        product.workSteps.append(step)
        material.product = product
        product.materials.append(material)

        ctx.insert(product)
        try ctx.save()

        // Confirm children exist before deleting
        #expect(try ctx.fetch(FetchDescriptor<WorkStep>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<Material>()).count == 1)

        ctx.delete(product)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<Product>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<WorkStep>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Material>()).isEmpty)
    }

    // MARK: - Category CRUD

    @Test("Create a category and fetch it back")
    func createAndFetchCategory() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let category = Category(name: "Cutting Boards")
        ctx.insert(category)
        try ctx.save()

        let results = try ctx.fetch(FetchDescriptor<Category>())
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
        let categories = try ctx.fetch(FetchDescriptor<Category>())
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
}
