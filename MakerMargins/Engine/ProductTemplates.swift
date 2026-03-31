// ProductTemplates.swift
// MakerMargins
//
// Pure-data definitions for starter product templates.
// Each template describes a complete product with work steps, materials,
// and pricing — ready for TemplateApplier to hydrate into SwiftData entities.
//
// No SwiftData dependency. Structs mirror model initializer signatures so
// TemplateApplier can map fields directly. Per-product join-model fields
// (laborRate, unitsRequiredPerProduct) are included alongside entity fields.

import Foundation

// MARK: - Template Data Structures

/// Blueprint for a shared WorkStep entity plus its ProductWorkStep join-model fields.
struct WorkStepTemplate {
    let title: String
    let summary: String
    let imageName: String               // Asset catalog name — empty string means no image
    let recordedTime: TimeInterval      // seconds — maps to WorkStep.recordedTime
    let batchUnitsCompleted: Decimal    // maps to WorkStep.batchUnitsCompleted
    let unitName: String                // maps to WorkStep.unitName
    let defaultUnitsPerProduct: Decimal // maps to WorkStep.defaultUnitsPerProduct
    let unitsRequiredPerProduct: Decimal // maps to ProductWorkStep.unitsRequiredPerProduct
    let laborRate: Decimal              // maps to ProductWorkStep.laborRate ($/hr)
}

/// Blueprint for a shared Material entity plus its ProductMaterial join-model fields.
struct MaterialTemplate {
    let title: String
    let summary: String
    let imageName: String               // Asset catalog name — empty string means no image
    let link: String                    // supplier URL — maps to Material.link
    let bulkCost: Decimal               // maps to Material.bulkCost
    let bulkQuantity: Decimal           // maps to Material.bulkQuantity
    let unitName: String                // maps to Material.unitName
    let defaultUnitsPerProduct: Decimal // maps to Material.defaultUnitsPerProduct
    let unitsRequiredPerProduct: Decimal // maps to ProductMaterial.unitsRequiredPerProduct
}

/// Blueprint for a ProductPricing record.
/// `platformType` is a raw String matching PlatformType's raw value
/// ("General", "Etsy", "Shopify", "Amazon") to avoid importing SwiftData.
struct PricingTemplate {
    let platformType: String
    let platformFee: Decimal
    let paymentProcessingFee: Decimal
    let marketingFee: Decimal
    let percentSalesFromMarketing: Decimal
    let profitMargin: Decimal
}

/// A complete product template with all child data.
/// `id` and `iconName` are for SwiftUI display only — not persisted.
struct ProductTemplate {
    let id: String
    let title: String
    let summary: String
    let iconName: String                // SF Symbol for the picker card
    let imageName: String               // Asset catalog name — empty string means no image
    let shippingCost: Decimal
    let materialBuffer: Decimal         // fraction (0.10 = 10%)
    let laborBuffer: Decimal            // fraction (0.05 = 5%)
    let workSteps: [WorkStepTemplate]
    let materials: [MaterialTemplate]
    let pricings: [PricingTemplate]
}

// MARK: - Catalog

enum ProductTemplates {

    static let all: [ProductTemplate] = [
        woodCuttingBoard,
        phoneStand3D,
        laserCoasterSet,
        soyCandle,
        resinEarrings
    ]

    // MARK: - Woodworking

    private static let woodCuttingBoard = ProductTemplate(
        id: "wood-cutting-board",
        title: "Hardwood Cutting Board",
        summary: "Edge-grain walnut and maple cutting board, 12\u{00D7}18 inches.",
        iconName: "hammer",
        imageName: "template-product-cutting-board",
        shippingCost: 12,
        materialBuffer: Decimal(string: "0.10")!,
        laborBuffer: Decimal(string: "0.05")!,
        workSteps: [
            WorkStepTemplate(
                title: "Rough Cut & Glue-Up",
                summary: "Cut boards to width, arrange grain, glue and clamp.",
                imageName: "template-step-rough-cut",
                recordedTime: 2700,
                batchUnitsCompleted: 2,
                unitName: "board",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 25
            ),
            WorkStepTemplate(
                title: "Sand & Flatten",
                summary: "Run through planer, sand 80 to 220 grit.",
                imageName: "template-step-sand-flatten",
                recordedTime: 1800,
                batchUnitsCompleted: 2,
                unitName: "board",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 25
            ),
            WorkStepTemplate(
                title: "Oil Finish",
                summary: "Apply 3 coats mineral oil, buff between coats.",
                imageName: "template-step-oil-finish",
                recordedTime: 1200,
                batchUnitsCompleted: 4,
                unitName: "board",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 20
            ),
            WorkStepTemplate(
                title: "Package",
                summary: "Wrap in tissue, box, and label for shipping.",
                imageName: "template-step-package",
                recordedTime: 600,
                batchUnitsCompleted: 4,
                unitName: "piece",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 15
            )
        ],
        materials: [
            MaterialTemplate(
                title: "Hardwood Lumber",
                summary: "4/4 walnut and maple, kiln-dried",
                imageName: "template-mat-hardwood-lumber",
                link: "",
                bulkCost: 60,
                bulkQuantity: 10,
                unitName: "board-foot",
                defaultUnitsPerProduct: 3,
                unitsRequiredPerProduct: 3
            ),
            MaterialTemplate(
                title: "Sandpaper Assortment",
                summary: "80, 120, 220 grit sheets",
                imageName: "template-mat-sandpaper",
                link: "",
                bulkCost: 18,
                bulkQuantity: 30,
                unitName: "sheet",
                defaultUnitsPerProduct: 3,
                unitsRequiredPerProduct: 3
            ),
            MaterialTemplate(
                title: "Mineral Oil",
                summary: "Food-safe mineral oil, 32 oz bottle",
                imageName: "template-mat-mineral-oil",
                link: "",
                bulkCost: 12,
                bulkQuantity: 32,
                unitName: "oz",
                defaultUnitsPerProduct: 2,
                unitsRequiredPerProduct: 2
            ),
            MaterialTemplate(
                title: "Packaging",
                summary: "Kraft box, tissue paper, and branded sticker",
                imageName: "template-mat-packaging",
                link: "",
                bulkCost: 45,
                bulkQuantity: 25,
                unitName: "kit",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            )
        ],
        pricings: [
            PricingTemplate(
                platformType: "Etsy",
                platformFee: Decimal(string: "0.065")!,
                paymentProcessingFee: Decimal(string: "0.03")!,
                marketingFee: Decimal(string: "0.15")!,
                percentSalesFromMarketing: Decimal(string: "0.20")!,
                profitMargin: Decimal(string: "0.30")!
            )
        ]
    )

    // MARK: - 3D Printing

    private static let phoneStand3D = ProductTemplate(
        id: "3d-phone-stand",
        title: "3D Printed Phone Stand",
        summary: "Minimalist phone stand, PLA filament, painted finish.",
        iconName: "cube",
        imageName: "",
        shippingCost: Decimal(string: "5.50")!,
        materialBuffer: Decimal(string: "0.05")!,
        laborBuffer: Decimal(string: "0.05")!,
        workSteps: [
            WorkStepTemplate(
                title: "3D Print",
                summary: "Print on FDM printer, 4.5 hours per unit.",
                imageName: "",
                recordedTime: 16200,
                batchUnitsCompleted: 1,
                unitName: "piece",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 3
            ),
            WorkStepTemplate(
                title: "Post-Process & Clean",
                summary: "Remove supports, sand layer lines.",
                imageName: "",
                recordedTime: 1200,
                batchUnitsCompleted: 3,
                unitName: "piece",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 18
            ),
            WorkStepTemplate(
                title: "Paint",
                summary: "Prime, paint 2 coats, clear coat.",
                imageName: "",
                recordedTime: 1500,
                batchUnitsCompleted: 3,
                unitName: "piece",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 18
            ),
            WorkStepTemplate(
                title: "Package",
                summary: "Wrap in tissue, box, and label for shipping.",
                imageName: "template-step-package",
                recordedTime: 600,
                batchUnitsCompleted: 4,
                unitName: "piece",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 15
            )
        ],
        materials: [
            MaterialTemplate(
                title: "PLA Filament",
                summary: "1 kg spool, standard colors",
                imageName: "",
                link: "",
                bulkCost: 22,
                bulkQuantity: 1000,
                unitName: "gram",
                defaultUnitsPerProduct: 85,
                unitsRequiredPerProduct: 85
            ),
            MaterialTemplate(
                title: "Sandpaper Assortment",
                summary: "80, 120, 220 grit sheets",
                imageName: "template-mat-sandpaper",
                link: "",
                bulkCost: 18,
                bulkQuantity: 30,
                unitName: "sheet",
                defaultUnitsPerProduct: 3,
                unitsRequiredPerProduct: 1
            ),
            MaterialTemplate(
                title: "Spray Paint",
                summary: "Primer, color, and clear coat cans",
                imageName: "",
                link: "",
                bulkCost: 24,
                bulkQuantity: 20,
                unitName: "unit",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            ),
            MaterialTemplate(
                title: "Packaging",
                summary: "Kraft box, tissue paper, and branded sticker",
                imageName: "template-mat-packaging",
                link: "",
                bulkCost: 45,
                bulkQuantity: 25,
                unitName: "kit",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            )
        ],
        pricings: [
            PricingTemplate(
                platformType: "Etsy",
                platformFee: Decimal(string: "0.065")!,
                paymentProcessingFee: Decimal(string: "0.03")!,
                marketingFee: Decimal(string: "0.15")!,
                percentSalesFromMarketing: Decimal(string: "0.15")!,
                profitMargin: Decimal(string: "0.35")!
            )
        ]
    )

    // MARK: - Laser Engraving

    private static let laserCoasterSet = ProductTemplate(
        id: "laser-coaster-set",
        title: "Laser Engraved Coaster Set",
        summary: "Set of 4 birch plywood coasters with custom engraving.",
        iconName: "target",
        imageName: "",
        shippingCost: 6,
        materialBuffer: Decimal(string: "0.08")!,
        laborBuffer: Decimal(string: "0.05")!,
        workSteps: [
            WorkStepTemplate(
                title: "Design Prep",
                summary: "Prepare vector artwork and laser settings.",
                imageName: "",
                recordedTime: 1200,
                batchUnitsCompleted: 1,
                unitName: "set",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 30
            ),
            WorkStepTemplate(
                title: "Laser Engrave",
                summary: "Engrave 4 coasters on laser cutter.",
                imageName: "",
                recordedTime: 2400,
                batchUnitsCompleted: 1,
                unitName: "set",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 8
            ),
            WorkStepTemplate(
                title: "Sand & Clean",
                summary: "Remove masking, light sand, wipe clean.",
                imageName: "",
                recordedTime: 900,
                batchUnitsCompleted: 2,
                unitName: "set",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 18
            ),
            WorkStepTemplate(
                title: "Package",
                summary: "Wrap in tissue, box, and label for shipping.",
                imageName: "template-step-package",
                recordedTime: 600,
                batchUnitsCompleted: 4,
                unitName: "piece",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 15
            )
        ],
        materials: [
            MaterialTemplate(
                title: "Birch Plywood Rounds",
                summary: "3mm birch plywood, 4-inch rounds, pre-cut",
                imageName: "",
                link: "",
                bulkCost: 28,
                bulkQuantity: 50,
                unitName: "round",
                defaultUnitsPerProduct: 4,
                unitsRequiredPerProduct: 4
            ),
            MaterialTemplate(
                title: "Masking Tape",
                summary: "Transfer tape for laser masking",
                imageName: "",
                link: "",
                bulkCost: 15,
                bulkQuantity: 100,
                unitName: "sheet",
                defaultUnitsPerProduct: 4,
                unitsRequiredPerProduct: 4
            ),
            MaterialTemplate(
                title: "Finish Spray",
                summary: "Polyurethane satin clear coat",
                imageName: "",
                link: "",
                bulkCost: 14,
                bulkQuantity: 30,
                unitName: "unit",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            ),
            MaterialTemplate(
                title: "Packaging",
                summary: "Kraft box, tissue paper, and branded sticker",
                imageName: "template-mat-packaging",
                link: "",
                bulkCost: 45,
                bulkQuantity: 25,
                unitName: "kit",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            )
        ],
        pricings: [
            PricingTemplate(
                platformType: "Etsy",
                platformFee: Decimal(string: "0.065")!,
                paymentProcessingFee: Decimal(string: "0.03")!,
                marketingFee: Decimal(string: "0.15")!,
                percentSalesFromMarketing: Decimal(string: "0.25")!,
                profitMargin: Decimal(string: "0.30")!
            )
        ]
    )

    // MARK: - Candle Making

    private static let soyCandle = ProductTemplate(
        id: "soy-candle",
        title: "Hand-Poured Soy Candle",
        summary: "8 oz soy wax candle in glass jar with cotton wick.",
        iconName: "flame",
        imageName: "",
        shippingCost: Decimal(string: "7.50")!,
        materialBuffer: Decimal(string: "0.10")!,
        laborBuffer: Decimal(string: "0.05")!,
        workSteps: [
            WorkStepTemplate(
                title: "Melt & Mix Wax",
                summary: "Melt soy wax, add fragrance oil at correct temperature.",
                imageName: "",
                recordedTime: 1800,
                batchUnitsCompleted: 8,
                unitName: "candle",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 20
            ),
            WorkStepTemplate(
                title: "Pour Candles",
                summary: "Center wicks, pour wax, top off after cooling.",
                imageName: "",
                recordedTime: 1200,
                batchUnitsCompleted: 8,
                unitName: "candle",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 20
            ),
            WorkStepTemplate(
                title: "Cure & Trim",
                summary: "Cure 48 hours, trim wick to 1/4 inch.",
                imageName: "",
                recordedTime: 600,
                batchUnitsCompleted: 8,
                unitName: "candle",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 15
            ),
            WorkStepTemplate(
                title: "Label & Package",
                summary: "Apply label, wrap, box for shipping.",
                imageName: "",
                recordedTime: 480,
                batchUnitsCompleted: 4,
                unitName: "candle",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 15
            )
        ],
        materials: [
            MaterialTemplate(
                title: "Soy Wax",
                summary: "Natural soy wax flakes, 10 lb bag",
                imageName: "",
                link: "",
                bulkCost: 25,
                bulkQuantity: 160,
                unitName: "oz",
                defaultUnitsPerProduct: 8,
                unitsRequiredPerProduct: 8
            ),
            MaterialTemplate(
                title: "Fragrance Oil",
                summary: "Premium candle fragrance, 16 oz bottle",
                imageName: "",
                link: "",
                bulkCost: 18,
                bulkQuantity: 16,
                unitName: "oz",
                defaultUnitsPerProduct: Decimal(string: "0.8")!,
                unitsRequiredPerProduct: Decimal(string: "0.8")!
            ),
            MaterialTemplate(
                title: "Cotton Wicks",
                summary: "Pre-tabbed cotton wicks, 100-pack",
                imageName: "",
                link: "",
                bulkCost: 8,
                bulkQuantity: 100,
                unitName: "wick",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            ),
            MaterialTemplate(
                title: "Glass Jars",
                summary: "8 oz glass candle jars with lids, 24-pack",
                imageName: "",
                link: "",
                bulkCost: 36,
                bulkQuantity: 24,
                unitName: "jar",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            ),
            MaterialTemplate(
                title: "Labels",
                summary: "Custom printed labels, 100-count roll",
                imageName: "",
                link: "",
                bulkCost: 15,
                bulkQuantity: 100,
                unitName: "label",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            )
        ],
        pricings: [
            PricingTemplate(
                platformType: "Etsy",
                platformFee: Decimal(string: "0.065")!,
                paymentProcessingFee: Decimal(string: "0.03")!,
                marketingFee: Decimal(string: "0.15")!,
                percentSalesFromMarketing: Decimal(string: "0.20")!,
                profitMargin: Decimal(string: "0.35")!
            )
        ]
    )

    // MARK: - Jewelry / Resin Art

    private static let resinEarrings = ProductTemplate(
        id: "resin-earrings",
        title: "Resin Earrings",
        summary: "Handmade epoxy resin earrings with embedded pigment.",
        iconName: "sparkles",
        imageName: "",
        shippingCost: 4,
        materialBuffer: Decimal(string: "0.08")!,
        laborBuffer: Decimal(string: "0.10")!,
        workSteps: [
            WorkStepTemplate(
                title: "Mix Resin",
                summary: "Measure and mix epoxy resin with hardener and pigment.",
                imageName: "",
                recordedTime: 900,
                batchUnitsCompleted: 6,
                unitName: "pair",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 22
            ),
            WorkStepTemplate(
                title: "Pour & Cure",
                summary: "Pour into molds, pop bubbles, cure 24 hours.",
                imageName: "",
                recordedTime: 600,
                batchUnitsCompleted: 6,
                unitName: "pair",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 22
            ),
            WorkStepTemplate(
                title: "Sand & Polish",
                summary: "Demold, wet sand 400 to 1500 grit, polish to shine.",
                imageName: "",
                recordedTime: 1800,
                batchUnitsCompleted: 3,
                unitName: "pair",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 22
            ),
            WorkStepTemplate(
                title: "Assemble Hardware",
                summary: "Attach earring hooks with jump rings.",
                imageName: "",
                recordedTime: 600,
                batchUnitsCompleted: 6,
                unitName: "pair",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 18
            ),
            WorkStepTemplate(
                title: "Package",
                summary: "Wrap in tissue, box, and label for shipping.",
                imageName: "template-step-package",
                recordedTime: 600,
                batchUnitsCompleted: 4,
                unitName: "piece",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1,
                laborRate: 15
            )
        ],
        materials: [
            MaterialTemplate(
                title: "Epoxy Resin",
                summary: "Crystal clear epoxy, 32 oz kit",
                imageName: "",
                link: "",
                bulkCost: 35,
                bulkQuantity: 32,
                unitName: "oz",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            ),
            MaterialTemplate(
                title: "Resin Pigment",
                summary: "Mica powder pigment set, 12 colors",
                imageName: "",
                link: "",
                bulkCost: 14,
                bulkQuantity: 120,
                unitName: "gram",
                defaultUnitsPerProduct: 2,
                unitsRequiredPerProduct: 2
            ),
            MaterialTemplate(
                title: "Earring Hooks",
                summary: "Hypoallergenic stainless steel hooks, 100 pair",
                imageName: "",
                link: "",
                bulkCost: 10,
                bulkQuantity: 100,
                unitName: "pair",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            ),
            MaterialTemplate(
                title: "Backing Cards",
                summary: "Custom printed earring display cards, 50-pack",
                imageName: "",
                link: "",
                bulkCost: 12,
                bulkQuantity: 50,
                unitName: "card",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            ),
            MaterialTemplate(
                title: "Poly Bags",
                summary: "Clear resealable bags, 3x4 inch, 200-pack",
                imageName: "",
                link: "",
                bulkCost: 6,
                bulkQuantity: 200,
                unitName: "bag",
                defaultUnitsPerProduct: 1,
                unitsRequiredPerProduct: 1
            )
        ],
        pricings: [
            PricingTemplate(
                platformType: "Etsy",
                platformFee: Decimal(string: "0.065")!,
                paymentProcessingFee: Decimal(string: "0.03")!,
                marketingFee: Decimal(string: "0.15")!,
                percentSalesFromMarketing: Decimal(string: "0.20")!,
                profitMargin: Decimal(string: "0.40")!
            )
        ]
    )
}
