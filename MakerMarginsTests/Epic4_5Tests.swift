// Epic4_5Tests.swift
// MakerMarginsTests
//
// E2E regression tests for Epic 4.5: Template Products.
// Covers template data integrity, TemplateApplier entity creation,
// title-based deduplication of shared WorkSteps and Materials,
// correct ProductPricing creation, and cross-template overlap.
//
// Each test creates its own isolated in-memory ModelContainer so tests
// never share state. Uses Swift Testing (import Testing, @Test, #expect).

import Testing
import Foundation
import SwiftData
@testable import MakerMargins

@MainActor
struct Epic4_5Tests {

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
            ProductPricing.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Template Data Integrity

    @Test("All templates have non-empty titles, summaries, and icon names")
    func templateFieldsAreNonEmpty() {
        let templates = ProductTemplates.all
        #expect(templates.count == 5)

        for template in templates {
            #expect(!template.id.isEmpty)
            #expect(!template.title.isEmpty)
            #expect(!template.summary.isEmpty)
            #expect(!template.iconName.isEmpty)
        }
    }

    @Test("All template work steps have valid batch data")
    func templateWorkStepsHaveValidData() {
        for template in ProductTemplates.all {
            #expect(!template.workSteps.isEmpty)
            for step in template.workSteps {
                #expect(!step.title.isEmpty)
                #expect(step.batchUnitsCompleted > 0)
                #expect(step.recordedTime >= 0)
                #expect(step.laborRate >= 0)
            }
        }
    }

    @Test("All template materials have valid bulk quantities")
    func templateMaterialsHaveValidData() {
        for template in ProductTemplates.all {
            #expect(!template.materials.isEmpty)
            for material in template.materials {
                #expect(!material.title.isEmpty)
                #expect(!material.unitName.isEmpty)
                #expect(material.bulkQuantity > 0)
                #expect(material.bulkCost >= 0)
            }
        }
    }

    // MARK: - Template Application

    @Test("Applying woodworking template creates product with correct fields")
    func applyWoodworkingTemplateProductFields() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let template = ProductTemplates.all[0]
        let product = try TemplateApplier.apply(template, to: ctx)
        try ctx.save()

        #expect(product.title == "Woodworking Template")
        #expect(product.sku == "TMPL-WOOD")
        #expect(product.shippingCost == 12)
        #expect(product.materialBuffer == Decimal(string: "0.10")!)
        #expect(product.laborBuffer == Decimal(string: "0.05")!)
    }

    @Test("Applying template creates correct work steps and join models")
    func applyTemplateCreatesWorkSteps() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let template = ProductTemplates.all[0]
        let product = try TemplateApplier.apply(template, to: ctx)
        try ctx.save()

        #expect(product.productWorkSteps.count == 4)

        let sorted = product.productWorkSteps.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted[0].workStep?.title == "Rough Cut & Glue-Up")
        #expect(sorted[0].sortOrder == 0)
        #expect(sorted[0].laborRate == 25)
        #expect(sorted[1].workStep?.title == "Sand & Flatten")
        #expect(sorted[1].sortOrder == 1)
        #expect(sorted[2].workStep?.title == "Oil Finish")
        #expect(sorted[2].sortOrder == 2)
        #expect(sorted[2].laborRate == 20)
        #expect(sorted[3].workStep?.title == "Package")
        #expect(sorted[3].sortOrder == 3)
        #expect(sorted[3].laborRate == 15)

        let allSteps = try ctx.fetch(FetchDescriptor<WorkStep>())
        #expect(allSteps.count == 4)
    }

    @Test("Applying template creates correct materials and join models")
    func applyTemplateCreatesMaterials() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let template = ProductTemplates.all[0]
        let product = try TemplateApplier.apply(template, to: ctx)
        try ctx.save()

        #expect(product.productMaterials.count == 4)

        let sorted = product.productMaterials.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted[0].material?.title == "Hardwood Lumber")
        #expect(sorted[0].sortOrder == 0)
        #expect(sorted[0].unitsRequiredPerProduct == 3)
        #expect(sorted[1].material?.title == "Sandpaper Assortment")
        #expect(sorted[1].sortOrder == 1)
        #expect(sorted[2].material?.title == "Mineral Oil")
        #expect(sorted[2].sortOrder == 2)
        #expect(sorted[3].material?.title == "Packaging")
        #expect(sorted[3].sortOrder == 3)

        let allMats = try ctx.fetch(FetchDescriptor<Material>())
        #expect(allMats.count == 4)
    }

    @Test("Applying template creates ProductPricing with correct platform and fees")
    func applyTemplateCreatesPricing() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let template = ProductTemplates.all[0]
        let product = try TemplateApplier.apply(template, to: ctx)
        try ctx.save()

        #expect(product.productPricings.count == 1)

        let pricing = product.productPricings[0]
        #expect(pricing.platformType == .etsy)
        #expect(pricing.platformFee == Decimal(string: "0.065")!)
        #expect(pricing.paymentProcessingFee == Decimal(string: "0.03")!)
        #expect(pricing.marketingFee == Decimal(string: "0.15")!)
        #expect(pricing.percentSalesFromMarketing == Decimal(string: "0.20")!)
        #expect(pricing.profitMargin == Decimal(string: "0.30")!)
    }

    // MARK: - Buffers and Shipping

    @Test("Candle template has correct shipping, material buffer, and labor buffer")
    func candleTemplateBuffersAndShipping() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let template = ProductTemplates.all[3]
        let product = try TemplateApplier.apply(template, to: ctx)
        try ctx.save()

        #expect(product.title == "Candle Making Template")
        #expect(product.shippingCost == Decimal(string: "7.50")!)
        #expect(product.materialBuffer == Decimal(string: "0.10")!)
        #expect(product.laborBuffer == Decimal(string: "0.05")!)
    }

    // MARK: - Deduplication

    @Test("Applying same template twice reuses existing WorkSteps")
    func deduplicateWorkStepsSameTemplate() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let template = ProductTemplates.all[0]
        let product1 = try TemplateApplier.apply(template, to: ctx)
        try ctx.save()
        let product2 = try TemplateApplier.apply(template, to: ctx)
        try ctx.save()

        let products = try ctx.fetch(FetchDescriptor<Product>())
        #expect(products.count == 2)
        #expect(product1.productWorkSteps.count == 4)
        #expect(product2.productWorkSteps.count == 4)

        // Only 4 WorkStep entities, not 8
        let allSteps = try ctx.fetch(FetchDescriptor<WorkStep>())
        #expect(allSteps.count == 4)

        // 8 join models total
        let allLinks = try ctx.fetch(FetchDescriptor<ProductWorkStep>())
        #expect(allLinks.count == 8)
    }

    @Test("Applying same template twice reuses existing Materials")
    func deduplicateMaterialsSameTemplate() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let template = ProductTemplates.all[0]
        let _ = try TemplateApplier.apply(template, to: ctx)
        try ctx.save()
        let _ = try TemplateApplier.apply(template, to: ctx)
        try ctx.save()

        // Only 4 Material entities, not 8
        let allMats = try ctx.fetch(FetchDescriptor<Material>())
        #expect(allMats.count == 4)

        // 8 join models total
        let allMatLinks = try ctx.fetch(FetchDescriptor<ProductMaterial>())
        #expect(allMatLinks.count == 8)
    }

    @Test("Two templates with overlapping materials share deduplicated entities")
    func deduplicateMaterialsAcrossTemplates() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Woodworking: Hardwood Lumber, Sandpaper Assortment, Mineral Oil, Packaging
        // 3D Printing: PLA Filament, Sandpaper Assortment, Spray Paint, Packaging
        // Overlap: "Sandpaper Assortment" + "Packaging" → 4 + 4 - 2 = 6 unique
        let _ = try TemplateApplier.apply(ProductTemplates.all[0], to: ctx)
        try ctx.save()
        let _ = try TemplateApplier.apply(ProductTemplates.all[1], to: ctx)
        try ctx.save()

        let allMats = try ctx.fetch(FetchDescriptor<Material>())
        #expect(allMats.count == 6)

        // "Packaging" linked to both products
        let packaging = allMats.first { $0.title == "Packaging" }!
        #expect(packaging.productMaterials.count == 2)

        // "Sandpaper Assortment" linked to both products
        let sandpaper = allMats.first { $0.title == "Sandpaper Assortment" }!
        #expect(sandpaper.productMaterials.count == 2)
    }

    @Test("Two templates with overlapping work steps share deduplicated Package step")
    func deduplicateWorkStepsAcrossTemplates() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Woodworking: Rough Cut & Glue-Up, Sand & Flatten, Oil Finish, Package
        // 3D Printing: 3D Print, Post-Process & Clean, Paint, Package
        // Overlap: "Package" → 4 + 4 - 1 = 7 unique
        let _ = try TemplateApplier.apply(ProductTemplates.all[0], to: ctx)
        try ctx.save()
        let _ = try TemplateApplier.apply(ProductTemplates.all[1], to: ctx)
        try ctx.save()

        let allSteps = try ctx.fetch(FetchDescriptor<WorkStep>())
        #expect(allSteps.count == 7)

        // "Package" linked to both products
        let packageStep = allSteps.first { $0.title == "Package" }!
        #expect(packageStep.productWorkSteps.count == 2)
    }

    // MARK: - All Templates

    @Test("All five templates apply without error")
    func applyAllTemplates() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        for template in ProductTemplates.all {
            let _ = try TemplateApplier.apply(template, to: ctx)
            try ctx.save()
        }

        let products = try ctx.fetch(FetchDescriptor<Product>())
        #expect(products.count == 5)
    }

    @Test("All templates have actual prices set on their pricing templates")
    func templatePricingHasActualPrices() {
        for template in ProductTemplates.all {
            #expect(!template.pricings.isEmpty)
            for pricing in template.pricings {
                #expect(pricing.actualPrice > 0, "Template '\(template.title)' has actualPrice 0")
                #expect(pricing.actualShippingCharge >= 0)
            }
        }
    }

    @Test("TemplateApplier creates ProductPricing with actualPrice and actualShippingCharge")
    func applyTemplateCreatesPricingWithActualFields() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        // Woodworking template: actualPrice $89.99, actualShippingCharge $8.95
        let template = ProductTemplates.all[0]
        let product = try TemplateApplier.apply(template, to: ctx)
        try ctx.save()

        #expect(product.productPricings.count == 1)
        let pricing = product.productPricings[0]
        #expect(pricing.actualPrice == Decimal(string: "89.99")!)
        #expect(pricing.actualShippingCharge == Decimal(string: "8.95")!)
    }

    @Test("3D printing template pricing fees match template definition")
    func phoneStandPricingFees() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let template = ProductTemplates.all[1]
        let product = try TemplateApplier.apply(template, to: ctx)
        try ctx.save()

        #expect(product.productPricings.count == 1)

        let pricing = product.productPricings[0]
        #expect(pricing.platformType == .etsy)
        #expect(pricing.platformFee == Decimal(string: "0.065")!)
        #expect(pricing.paymentProcessingFee == Decimal(string: "0.03")!)
        #expect(pricing.marketingFee == Decimal(string: "0.15")!)
        #expect(pricing.percentSalesFromMarketing == Decimal(string: "0.15")!)
        #expect(pricing.profitMargin == Decimal(string: "0.35")!)
    }
}
