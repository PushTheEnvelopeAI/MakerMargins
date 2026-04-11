// ProductRepository.swift
// MakerMargins
//
// Writes-only repository for Product entities. Reads stay on @Query.
// Protocol exists for future sync-layer swap (SyncingProductRepository).
// See CLAUDE.md "Cross-Platform & Cloud Future" for context.

import Foundation
import SwiftData
import SwiftUI

// MARK: - Protocol

protocol ProductRepository {
    func create(
        title: String,
        sku: String,
        summary: String,
        image: Data?,
        shippingCost: Decimal,
        materialBuffer: Decimal,
        laborBuffer: Decimal,
        category: Category?
    ) -> Product

    func delete(_ product: Product)
    func duplicate(_ product: Product) -> Product
    func touch(_ product: Product)
}

// MARK: - SwiftData Implementation

final class SwiftDataProductRepository: ProductRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(
        title: String,
        sku: String = "",
        summary: String = "",
        image: Data? = nil,
        shippingCost: Decimal = 0,
        materialBuffer: Decimal = 0,
        laborBuffer: Decimal = 0,
        category: Category? = nil
    ) -> Product {
        let product = Product(
            title: title,
            sku: sku,
            summary: summary,
            image: image,
            shippingCost: shippingCost,
            materialBuffer: materialBuffer,
            laborBuffer: laborBuffer,
            category: category
        )
        context.insert(product)
        return product
    }

    func delete(_ product: Product) {
        product.updatedAt = .now
        context.delete(product)
    }

    func duplicate(_ product: Product) -> Product {
        let copy = Product(
            title: "\(product.title) Copy",
            sku: product.sku,
            summary: product.summary,
            image: product.image,
            shippingCost: product.shippingCost,
            materialBuffer: product.materialBuffer,
            laborBuffer: product.laborBuffer,
            category: product.category
        )
        context.insert(copy)

        // Deep copy work step associations
        for link in product.productWorkSteps.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let newLink = ProductWorkStep(
                product: copy,
                workStep: link.workStep,
                sortOrder: link.sortOrder,
                unitsRequiredPerProduct: link.unitsRequiredPerProduct,
                laborRate: link.laborRate
            )
            context.insert(newLink)
        }

        // Deep copy material associations
        for link in product.productMaterials.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let newLink = ProductMaterial(
                product: copy,
                material: link.material,
                sortOrder: link.sortOrder,
                unitsRequiredPerProduct: link.unitsRequiredPerProduct
            )
            context.insert(newLink)
        }

        // Deep copy pricing overrides
        for pricing in product.productPricings {
            let newPricing = ProductPricing(
                product: copy,
                platformType: pricing.platformType,
                platformFee: pricing.platformFee,
                paymentProcessingFee: pricing.paymentProcessingFee,
                marketingFee: pricing.marketingFee,
                percentSalesFromMarketing: pricing.percentSalesFromMarketing,
                profitMargin: pricing.profitMargin,
                actualPrice: pricing.actualPrice,
                actualShippingCharge: pricing.actualShippingCharge
            )
            context.insert(newPricing)
        }

        return copy
    }

    func touch(_ product: Product) {
        product.updatedAt = .now
    }
}

// MARK: - Environment Key

struct ProductRepositoryKey: EnvironmentKey {
    static let defaultValue: any ProductRepository = PlaceholderProductRepository()
}

extension EnvironmentValues {
    var productRepository: any ProductRepository {
        get { self[ProductRepositoryKey.self] }
        set { self[ProductRepositoryKey.self] = newValue }
    }
}

/// Placeholder that fatal-errors if called without injection. Prevents silent misuse.
private struct PlaceholderProductRepository: ProductRepository {
    func create(title: String, sku: String, summary: String, image: Data?, shippingCost: Decimal, materialBuffer: Decimal, laborBuffer: Decimal, category: Category?) -> Product {
        fatalError("ProductRepository not injected. Add .environment(\\.productRepository, ...) to the view hierarchy.")
    }
    func delete(_ product: Product) { fatalError("ProductRepository not injected.") }
    func duplicate(_ product: Product) -> Product { fatalError("ProductRepository not injected.") }
    func touch(_ product: Product) { fatalError("ProductRepository not injected.") }
}
