// WorkStepRepository.swift
// MakerMargins
//
// Writes-only repository for WorkStep entities and their ProductWorkStep joins.
// Reads stay on @Query. Protocol exists for future sync-layer swap.

import Foundation
import SwiftData
import SwiftUI

// MARK: - Protocol

protocol WorkStepRepository {
    func create(
        title: String,
        summary: String,
        image: Data?,
        recordedTime: TimeInterval,
        batchUnitsCompleted: Decimal,
        unitName: String,
        defaultUnitsPerProduct: Decimal
    ) -> WorkStep

    func delete(_ step: WorkStep)
    func touch(_ step: WorkStep)

    // Join management
    @discardableResult
    func addToProduct(
        _ step: WorkStep,
        product: Product,
        laborRate: Decimal,
        unitsRequired: Decimal,
        sortOrder: Int
    ) -> ProductWorkStep

    func removeFromProduct(_ link: ProductWorkStep)
    func reorder(_ links: [ProductWorkStep])
}

// MARK: - SwiftData Implementation

final class SwiftDataWorkStepRepository: WorkStepRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(
        title: String,
        summary: String = "",
        image: Data? = nil,
        recordedTime: TimeInterval = 0,
        batchUnitsCompleted: Decimal = 1,
        unitName: String = "unit",
        defaultUnitsPerProduct: Decimal = 1
    ) -> WorkStep {
        let step = WorkStep(
            title: title,
            summary: summary,
            image: image,
            recordedTime: recordedTime,
            batchUnitsCompleted: batchUnitsCompleted,
            unitName: unitName,
            defaultUnitsPerProduct: defaultUnitsPerProduct
        )
        context.insert(step)
        return step
    }

    func delete(_ step: WorkStep) {
        step.updatedAt = .now
        context.delete(step)
    }

    func touch(_ step: WorkStep) {
        step.updatedAt = .now
    }

    @discardableResult
    func addToProduct(
        _ step: WorkStep,
        product: Product,
        laborRate: Decimal,
        unitsRequired: Decimal,
        sortOrder: Int
    ) -> ProductWorkStep {
        let link = ProductWorkStep(
            product: product,
            workStep: step,
            sortOrder: sortOrder,
            unitsRequiredPerProduct: unitsRequired,
            laborRate: laborRate
        )
        context.insert(link)
        product.updatedAt = .now
        return link
    }

    func removeFromProduct(_ link: ProductWorkStep) {
        if let product = link.product {
            product.updatedAt = .now
        }
        context.delete(link)
    }

    func reorder(_ links: [ProductWorkStep]) {
        for (index, link) in links.enumerated() {
            link.sortOrder = index
        }
        if let product = links.first?.product {
            product.updatedAt = .now
        }
    }
}

// MARK: - Environment Key

struct WorkStepRepositoryKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: any WorkStepRepository = PlaceholderWorkStepRepository()
}

extension EnvironmentValues {
    var workStepRepository: any WorkStepRepository {
        get { self[WorkStepRepositoryKey.self] }
        set { self[WorkStepRepositoryKey.self] = newValue }
    }
}

private struct PlaceholderWorkStepRepository: WorkStepRepository {
    func create(title: String, summary: String, image: Data?, recordedTime: TimeInterval, batchUnitsCompleted: Decimal, unitName: String, defaultUnitsPerProduct: Decimal) -> WorkStep {
        fatalError("WorkStepRepository not injected.")
    }
    func delete(_ step: WorkStep) { fatalError("WorkStepRepository not injected.") }
    func touch(_ step: WorkStep) { fatalError("WorkStepRepository not injected.") }
    func addToProduct(_ step: WorkStep, product: Product, laborRate: Decimal, unitsRequired: Decimal, sortOrder: Int) -> ProductWorkStep {
        fatalError("WorkStepRepository not injected.")
    }
    func removeFromProduct(_ link: ProductWorkStep) { fatalError("WorkStepRepository not injected.") }
    func reorder(_ links: [ProductWorkStep]) { fatalError("WorkStepRepository not injected.") }
}
