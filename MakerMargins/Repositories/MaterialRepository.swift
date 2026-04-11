// MaterialRepository.swift
// MakerMargins
//
// Writes-only repository for Material entities and their ProductMaterial joins.
// Reads stay on @Query. Protocol exists for future sync-layer swap.

import Foundation
import SwiftData
import SwiftUI

// MARK: - Protocol

protocol MaterialRepository {
    func create(
        title: String,
        summary: String,
        image: Data?,
        link: String,
        bulkCost: Decimal,
        bulkQuantity: Decimal,
        unitName: String,
        defaultUnitsPerProduct: Decimal
    ) -> Material

    func delete(_ material: Material)
    func touch(_ material: Material)

    // Join management
    @discardableResult
    func addToProduct(
        _ material: Material,
        product: Product,
        unitsRequired: Decimal,
        sortOrder: Int
    ) -> ProductMaterial

    func removeFromProduct(_ link: ProductMaterial)
    func reorder(_ links: [ProductMaterial])
}

// MARK: - SwiftData Implementation

final class SwiftDataMaterialRepository: MaterialRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(
        title: String,
        summary: String = "",
        image: Data? = nil,
        link: String = "",
        bulkCost: Decimal = 0,
        bulkQuantity: Decimal = 1,
        unitName: String = "unit",
        defaultUnitsPerProduct: Decimal = 1
    ) -> Material {
        let material = Material(
            title: title,
            summary: summary,
            image: image,
            link: link,
            bulkCost: bulkCost,
            bulkQuantity: bulkQuantity,
            unitName: unitName,
            defaultUnitsPerProduct: defaultUnitsPerProduct
        )
        context.insert(material)
        return material
    }

    func delete(_ material: Material) {
        material.updatedAt = .now
        context.delete(material)
    }

    func touch(_ material: Material) {
        material.updatedAt = .now
    }

    @discardableResult
    func addToProduct(
        _ material: Material,
        product: Product,
        unitsRequired: Decimal,
        sortOrder: Int
    ) -> ProductMaterial {
        let link = ProductMaterial(
            product: product,
            material: material,
            sortOrder: sortOrder,
            unitsRequiredPerProduct: unitsRequired
        )
        context.insert(link)
        product.updatedAt = .now
        return link
    }

    func removeFromProduct(_ link: ProductMaterial) {
        if let product = link.product {
            product.updatedAt = .now
        }
        context.delete(link)
    }

    func reorder(_ links: [ProductMaterial]) {
        for (index, link) in links.enumerated() {
            link.sortOrder = index
        }
        if let product = links.first?.product {
            product.updatedAt = .now
        }
    }
}

// MARK: - Environment Key

struct MaterialRepositoryKey: EnvironmentKey {
    static let defaultValue: any MaterialRepository = PlaceholderMaterialRepository()
}

extension EnvironmentValues {
    var materialRepository: any MaterialRepository {
        get { self[MaterialRepositoryKey.self] }
        set { self[MaterialRepositoryKey.self] = newValue }
    }
}

private struct PlaceholderMaterialRepository: MaterialRepository {
    func create(title: String, summary: String, image: Data?, link: String, bulkCost: Decimal, bulkQuantity: Decimal, unitName: String, defaultUnitsPerProduct: Decimal) -> Material {
        fatalError("MaterialRepository not injected.")
    }
    func delete(_ material: Material) { fatalError("MaterialRepository not injected.") }
    func touch(_ material: Material) { fatalError("MaterialRepository not injected.") }
    func addToProduct(_ material: Material, product: Product, unitsRequired: Decimal, sortOrder: Int) -> ProductMaterial {
        fatalError("MaterialRepository not injected.")
    }
    func removeFromProduct(_ link: ProductMaterial) { fatalError("MaterialRepository not injected.") }
    func reorder(_ links: [ProductMaterial]) { fatalError("MaterialRepository not injected.") }
}
