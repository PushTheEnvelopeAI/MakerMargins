// TemplateApplier.swift
// MakerMargins
//
// Hydrates a ProductTemplate into SwiftData entities.
// Creates a Product with linked WorkSteps, Materials, join models,
// and ProductPricing records. Shared WorkSteps and Materials are
// deduplicated by title — if an entity with a matching title already
// exists, it is reused and only a new join model is created.

import Foundation
import SwiftData
import UIKit

enum TemplateApplier {

    // MARK: - Apply Template

    /// Creates a fully-populated Product from a template.
    ///
    /// Shared WorkSteps and Materials are deduplicated by title — if an entity
    /// with a matching title already exists in the store, it is reused and only
    /// a new join model is created. Returns the newly created Product.
    @MainActor
    static func apply(
        _ template: ProductTemplate,
        to context: ModelContext
    ) throws -> Product {

        // Fetch existing entities once for dedup lookups.
        let existingSteps = (try? context.fetch(FetchDescriptor<WorkStep>())) ?? []
        let existingMaterials = (try? context.fetch(FetchDescriptor<Material>())) ?? []

        // 1. Create the product.
        let product = Product(
            title: template.title,
            sku: template.sku,
            summary: template.summary,
            image: loadImageData(named: template.imageName),
            shippingCost: template.shippingCost,
            materialBuffer: template.materialBuffer,
            laborBuffer: template.laborBuffer
        )
        context.insert(product)

        // 2. Link work steps (reuse existing by title or create new).
        for (index, stepTemplate) in template.workSteps.enumerated() {
            let step = existingSteps.first { $0.title == stepTemplate.title }
                ?? createWorkStep(from: stepTemplate, in: context)

            let link = ProductWorkStep(
                product: product,
                workStep: step,
                sortOrder: index,
                unitsRequiredPerProduct: stepTemplate.unitsRequiredPerProduct,
                laborRate: stepTemplate.laborRate
            )
            context.insert(link)
            product.productWorkSteps.append(link)
            step.productWorkSteps.append(link)
        }

        // 3. Link materials (reuse existing by title or create new).
        for (index, matTemplate) in template.materials.enumerated() {
            let material = existingMaterials.first { $0.title == matTemplate.title }
                ?? createMaterial(from: matTemplate, in: context)

            let matLink = ProductMaterial(
                product: product,
                material: material,
                sortOrder: index,
                unitsRequiredPerProduct: matTemplate.unitsRequiredPerProduct
            )
            context.insert(matLink)
            product.productMaterials.append(matLink)
            material.productMaterials.append(matLink)
        }

        // 4. Create per-platform pricing records.
        for pricingTemplate in template.pricings {
            guard let platformType = PlatformType(rawValue: pricingTemplate.platformType) else {
                continue
            }
            let pricing = ProductPricing(
                product: product,
                platformType: platformType,
                platformFee: pricingTemplate.platformFee,
                paymentProcessingFee: pricingTemplate.paymentProcessingFee,
                marketingFee: pricingTemplate.marketingFee,
                percentSalesFromMarketing: pricingTemplate.percentSalesFromMarketing,
                profitMargin: pricingTemplate.profitMargin
            )
            context.insert(pricing)
        }

        return product
    }

    // MARK: - Private Helpers

    @MainActor
    private static func createWorkStep(
        from template: WorkStepTemplate,
        in context: ModelContext
    ) -> WorkStep {
        let step = WorkStep(
            title: template.title,
            summary: template.summary,
            image: loadImageData(named: template.imageName),
            recordedTime: template.recordedTime,
            batchUnitsCompleted: template.batchUnitsCompleted,
            unitName: template.unitName,
            defaultUnitsPerProduct: template.defaultUnitsPerProduct
        )
        context.insert(step)
        return step
    }

    @MainActor
    private static func createMaterial(
        from template: MaterialTemplate,
        in context: ModelContext
    ) -> Material {
        let material = Material(
            title: template.title,
            summary: template.summary,
            image: loadImageData(named: template.imageName),
            link: template.link,
            bulkCost: template.bulkCost,
            bulkQuantity: template.bulkQuantity,
            unitName: template.unitName,
            defaultUnitsPerProduct: template.defaultUnitsPerProduct
        )
        context.insert(material)
        return material
    }

    /// Loads image data from the asset catalog. Returns nil for empty names
    /// or missing assets, so templates without images gracefully get no image.
    private static func loadImageData(named name: String) -> Data? {
        guard !name.isEmpty else { return nil }
        return UIImage(named: name)?.jpegData(compressionQuality: 0.8)
    }
}
