// ProductTemplates.swift
// MakerMargins
//
// Pure-data definitions for starter product templates.
// Each template describes a complete product with work steps, materials,
//
private func d(_ s: String) -> Decimal { Decimal(string: s) ?? 0 }
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
    let actualPrice: Decimal              // maps to ProductPricing.actualPrice
    let actualShippingCharge: Decimal     // maps to ProductPricing.actualShippingCharge
}

/// A complete product template with all child data.
/// `id` and `iconName` are for SwiftUI display only — not persisted.
struct ProductTemplate {
    let id: String
    let title: String
    let sku: String
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
        title: "Woodworking Template",
        sku: "TMPL-WOOD",
        summary: "A typical woodworking product with cutting, sanding, finishing, and packaging steps.",
        iconName: "hammer",
        imageName: "template-product-cutting-board",
        shippingCost: 12,
        materialBuffer: d("0.10"),
        laborBuffer: d("0.05"),
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
                platformFee: d("0.065"),
                paymentProcessingFee: d("0.03"),
                marketingFee: d("0.15"),
                percentSalesFromMarketing: d("0.20"),
                profitMargin: d("0.30"),
                actualPrice: d("89.99"),
                actualShippingCharge: d("8.95")
            )
        ]
    )

    // MARK: - 3D Printing

    private static let phoneStand3D = ProductTemplate(
        id: "3d-phone-stand",
        title: "3D Printing Template",
        sku: "TMPL-3DP",
        summary: "A typical 3D printed product with printing, post-processing, painting, and packaging steps.",
        iconName: "cube",
        imageName: "template-product-phone-stand",
        shippingCost: d("5.50"),
        materialBuffer: d("0.05"),
        laborBuffer: d("0.05"),
        workSteps: [
            WorkStepTemplate(
                title: "3D Print",
                summary: "Print on FDM printer, 4.5 hours per unit.",
                imageName: "template-step-3d-print",
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
                imageName: "template-step-post-process",
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
                imageName: "template-step-paint",
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
                imageName: "template-mat-pla-filament",
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
                imageName: "template-mat-spray-paint",
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
                platformFee: d("0.065"),
                paymentProcessingFee: d("0.03"),
                marketingFee: d("0.15"),
                percentSalesFromMarketing: d("0.15"),
                profitMargin: d("0.35"),
                actualPrice: d("49.99"),
                actualShippingCharge: d("5.50")
            )
        ]
    )

    // MARK: - Laser Engraving

    private static let laserCoasterSet = ProductTemplate(
        id: "laser-coaster-set",
        title: "Laser Engraving Template",
        sku: "TMPL-LASER",
        summary: "A typical laser engraving product with design, engraving, finishing, and packaging steps.",
        iconName: "target",
        imageName: "template-product-coaster-set",
        shippingCost: 6,
        materialBuffer: d("0.08"),
        laborBuffer: d("0.05"),
        workSteps: [
            WorkStepTemplate(
                title: "Design Prep",
                summary: "Prepare vector artwork and laser settings.",
                imageName: "template-step-design-prep",
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
                imageName: "template-step-laser-engrave",
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
                imageName: "template-step-sand-clean",
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
                imageName: "template-mat-plywood-rounds",
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
                imageName: "template-mat-masking-tape",
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
                imageName: "template-mat-finish-spray",
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
                platformFee: d("0.065"),
                paymentProcessingFee: d("0.03"),
                marketingFee: d("0.15"),
                percentSalesFromMarketing: d("0.25"),
                profitMargin: d("0.30"),
                actualPrice: d("52.00"),
                actualShippingCharge: d("6.50")
            )
        ]
    )

    // MARK: - Candle Making

    private static let soyCandle = ProductTemplate(
        id: "soy-candle",
        title: "Candle Making Template",
        sku: "TMPL-CANDLE",
        summary: "A typical candle making product with melting, pouring, curing, and packaging steps.",
        iconName: "flame",
        imageName: "template-product-soy-candle",
        shippingCost: d("7.50"),
        materialBuffer: d("0.10"),
        laborBuffer: d("0.05"),
        workSteps: [
            WorkStepTemplate(
                title: "Melt & Mix Wax",
                summary: "Melt soy wax, add fragrance oil at correct temperature.",
                imageName: "template-step-melt-mix",
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
                imageName: "template-step-pour-candles",
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
                imageName: "template-step-cure-trim",
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
                imageName: "template-step-label-package",
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
                imageName: "template-mat-soy-wax",
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
                imageName: "template-mat-fragrance-oil",
                link: "",
                bulkCost: 18,
                bulkQuantity: 16,
                unitName: "oz",
                defaultUnitsPerProduct: d("0.8"),
                unitsRequiredPerProduct: d("0.8")
            ),
            MaterialTemplate(
                title: "Cotton Wicks",
                summary: "Pre-tabbed cotton wicks, 100-pack",
                imageName: "template-mat-cotton-wicks",
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
                imageName: "template-mat-glass-jars",
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
                imageName: "template-mat-labels",
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
                platformFee: d("0.065"),
                paymentProcessingFee: d("0.03"),
                marketingFee: d("0.15"),
                percentSalesFromMarketing: d("0.20"),
                profitMargin: d("0.35"),
                actualPrice: d("24.99"),
                actualShippingCharge: d("5.99")
            )
        ]
    )

    // MARK: - Jewelry / Resin Art

    private static let resinEarrings = ProductTemplate(
        id: "resin-earrings",
        title: "Resin Art Template",
        sku: "TMPL-RESIN",
        summary: "A typical resin art product with mixing, molding, polishing, and assembly steps.",
        iconName: "sparkles",
        imageName: "template-product-resin-earrings",
        shippingCost: 4,
        materialBuffer: d("0.08"),
        laborBuffer: d("0.10"),
        workSteps: [
            WorkStepTemplate(
                title: "Mix Resin",
                summary: "Measure and mix epoxy resin with hardener and pigment.",
                imageName: "template-step-mix-resin",
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
                imageName: "template-step-pour-cure",
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
                imageName: "template-step-sand-polish",
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
                imageName: "template-step-assemble-hardware",
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
                imageName: "template-mat-epoxy-resin",
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
                imageName: "template-mat-resin-pigment",
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
                imageName: "template-mat-earring-hooks",
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
                imageName: "template-mat-backing-cards",
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
                imageName: "template-mat-poly-bags",
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
                platformFee: d("0.065"),
                paymentProcessingFee: d("0.03"),
                marketingFee: d("0.15"),
                percentSalesFromMarketing: d("0.20"),
                profitMargin: d("0.40"),
                actualPrice: d("22.00"),
                actualShippingCharge: d("4.50")
            )
        ]
    )
}
