# Epic 4.5 — Template Products

## Context

New users opening MakerMargins for the first time see an empty product list with no sense of what the app can do. Template products solve this by letting users create a fully-populated product (with work steps, materials, buffers, shipping, and pricing) in one tap. This showcases the app's full feature set — varying labor rates, batch sizing, material costing, buffers, and platform-specific pricing — while giving users a realistic starting point they can customize.

Key requirement: shared WorkSteps and Materials must be **deduplicated by title**. If a user applies two templates that both include "Packaging", only one Material entity is created; both products link to it via their own join models.

---

## Files to Create

| File | Purpose |
|------|---------|
| `MakerMargins/Engine/ProductTemplates.swift` | Pure Swift structs defining all 5 templates (no SwiftData import) |
| `MakerMargins/Engine/TemplateApplier.swift` | SwiftData creation logic with title-based deduplication |
| `MakerMargins/Views/Products/TemplatePickerView.swift` | Sheet UI for browsing and selecting templates |
| `MakerMarginsTests/Epic4_5Tests.swift` | Full test suite (14 tests) |

## Files to Modify

| File | Change |
|------|--------|
| `MakerMargins/Views/Products/ProductListView.swift` | Toolbar "+" becomes a Menu (Blank Product / From Template); add template picker sheet; update empty state text |

No model changes. No schema migration. No changes to `project.yml` or `MakerMarginsApp.swift` (XcodeGen auto-discovers new files).

---

## Step 1: Template Data Structs (`Engine/ProductTemplates.swift`)

Import only `Foundation`. Define plain structs that mirror model initializer fields:

```swift
struct WorkStepTemplate {
    let title: String
    let summary: String
    let recordedTime: TimeInterval      // seconds
    let batchUnitsCompleted: Decimal
    let unitName: String
    let defaultUnitsPerProduct: Decimal
    // Join-model (per-product) fields:
    let unitsRequiredPerProduct: Decimal
    let laborRate: Decimal              // $/hr
}

struct MaterialTemplate {
    let title: String
    let summary: String
    let link: String                    // supplier URL, usually ""
    let bulkCost: Decimal
    let bulkQuantity: Decimal
    let unitName: String
    let defaultUnitsPerProduct: Decimal
    // Join-model field:
    let unitsRequiredPerProduct: Decimal
}

struct PricingTemplate {
    let platformType: String            // PlatformType raw value ("Etsy", etc.)
    let platformFee: Decimal
    let paymentProcessingFee: Decimal
    let marketingFee: Decimal
    let percentSalesFromMarketing: Decimal
    let profitMargin: Decimal
}

struct ProductTemplate {
    let id: String                      // stable SwiftUI identity key
    let title: String
    let summary: String
    let iconName: String                // SF Symbol
    let shippingCost: Decimal
    let materialBuffer: Decimal
    let laborBuffer: Decimal
    let workSteps: [WorkStepTemplate]
    let materials: [MaterialTemplate]
    let pricings: [PricingTemplate]
}

enum ProductTemplates {
    static let all: [ProductTemplate] = [
        woodCuttingBoard, phoneStand3D, laserCoasterSet,
        soyCandle, resinEarrings
    ]
}
```

---

## Step 2: Template Content — 5 Templates

### Template 1: Hardwood Cutting Board (Woodworking)
**`id: "wood-cutting-board"` / `iconName: "hammer"`**

Product: shippingCost: 12, materialBuffer: 0.10, laborBuffer: 0.05

**WorkSteps (4):**

| # | Title | Time (s) | Batch | Unit | Units/Prod | Rate |
|---|-------|----------|-------|------|------------|------|
| 0 | Rough Cut & Glue-Up | 2700 (45m) | 2 | board | 1 | $25 |
| 1 | Sand & Flatten | 1800 (30m) | 2 | board | 1 | $25 |
| 2 | Oil Finish | 1200 (20m) | 4 | board | 1 | $20 |
| 3 | Package | 600 (10m) | 4 | piece | 1 | $15 |

**Materials (4):**

| # | Title | Bulk Cost | Qty | Unit | Units/Prod |
|---|-------|-----------|-----|------|------------|
| 0 | Hardwood Lumber | $60 | 10 | board-foot | 3 |
| 1 | Sandpaper Assortment | $18 | 30 | sheet | 3 |
| 2 | Mineral Oil | $12 | 32 | oz | 2 |
| 3 | Packaging | $45 | 25 | kit | 1 |

**Pricing:** Etsy, profitMargin: 0.30, percentSalesFromMarketing: 0.20
**Target price ~$97** (realistic for a handmade cutting board)

---

### Template 2: 3D Printed Phone Stand
**`id: "3d-phone-stand"` / `iconName: "cube"`**

Product: shippingCost: 5.50, materialBuffer: 0.05, laborBuffer: 0.05

**WorkSteps (4):**

| # | Title | Time (s) | Batch | Unit | Units/Prod | Rate |
|---|-------|----------|-------|------|------------|------|
| 0 | 3D Print | 16200 (4.5h) | 1 | piece | 1 | **$3** (machine time) |
| 1 | Post-Process & Clean | 1200 (20m) | 3 | piece | 1 | $18 |
| 2 | Paint | 1500 (25m) | 3 | piece | 1 | $18 |
| 3 | Package | 600 (10m) | 4 | piece | 1 | $15 |

**Materials (4):**

| # | Title | Bulk Cost | Qty | Unit | Units/Prod |
|---|-------|-----------|-----|------|------------|
| 0 | PLA Filament | $22 | 1000 | gram | 85 |
| 1 | Sandpaper Assortment | $18 | 30 | sheet | 1 |
| 2 | Spray Paint | $24 | 20 | unit | 1 |
| 3 | Packaging | $45 | 25 | kit | 1 |

**Pricing:** Etsy, profitMargin: 0.35, percentSalesFromMarketing: 0.15
**Shared with Template 1:** "Package" step, "Sandpaper Assortment", "Packaging"
**Showcases:** very low labor rate for machine time ($3/hr)

---

### Template 3: Laser Engraved Coaster Set
**`id: "laser-coaster-set"` / `iconName: "target"`**

Product: shippingCost: 6, materialBuffer: 0.08, laborBuffer: 0.05

**WorkSteps (4):**

| # | Title | Time (s) | Batch | Unit | Units/Prod | Rate |
|---|-------|----------|-------|------|------------|------|
| 0 | Design Prep | 1200 (20m) | 1 | set | 1 | **$30** (design skill) |
| 1 | Laser Engrave | 2400 (40m) | 1 | set | 1 | **$8** (machine time) |
| 2 | Sand & Clean | 900 (15m) | 2 | set | 1 | $18 |
| 3 | Package | 600 (10m) | 4 | piece | 1 | $15 |

**Materials (4):**

| # | Title | Bulk Cost | Qty | Unit | Units/Prod |
|---|-------|-----------|-----|------|------------|
| 0 | Birch Plywood Rounds | $28 | 50 | round | 4 |
| 1 | Masking Tape | $15 | 100 | sheet | 4 |
| 2 | Finish Spray | $14 | 30 | unit | 1 |
| 3 | Packaging | $45 | 25 | kit | 1 |

**Pricing:** Etsy, profitMargin: 0.30, percentSalesFromMarketing: 0.25
**Shared:** "Package" step, "Packaging" material
**Showcases:** high rate for design ($30/hr), low rate for machine ($8/hr)

---

### Template 4: Hand-Poured Soy Candle
**`id: "soy-candle"` / `iconName: "flame"`**

Product: shippingCost: 7.50, materialBuffer: 0.10, laborBuffer: 0.05

**WorkSteps (4):**

| # | Title | Time (s) | Batch | Unit | Units/Prod | Rate |
|---|-------|----------|-------|------|------------|------|
| 0 | Melt & Mix Wax | 1800 (30m) | 8 | candle | 1 | $20 |
| 1 | Pour Candles | 1200 (20m) | 8 | candle | 1 | $20 |
| 2 | Cure & Trim | 600 (10m) | 8 | candle | 1 | $15 |
| 3 | Label & Package | 480 (8m) | 4 | candle | 1 | $15 |

**Materials (5):**

| # | Title | Bulk Cost | Qty | Unit | Units/Prod |
|---|-------|-----------|-----|------|------------|
| 0 | Soy Wax | $25 | 160 | oz | 8 |
| 1 | Fragrance Oil | $18 | 16 | oz | 0.8 |
| 2 | Cotton Wicks | $8 | 100 | wick | 1 |
| 3 | Glass Jars | $36 | 24 | jar | 1 |
| 4 | Labels | $15 | 100 | label | 1 |

**Pricing:** Etsy, profitMargin: 0.35, percentSalesFromMarketing: 0.20
**No shared steps** (uses "Label & Package", distinct from "Package")
**Showcases:** large batch sizes (8 per melt), 5 materials, low per-unit labor

---

### Template 5: Resin Earrings
**`id: "resin-earrings"` / `iconName: "sparkles"`**

Product: shippingCost: 4, materialBuffer: 0.08, laborBuffer: 0.10

**WorkSteps (5):**

| # | Title | Time (s) | Batch | Unit | Units/Prod | Rate |
|---|-------|----------|-------|------|------------|------|
| 0 | Mix Resin | 900 (15m) | 6 | pair | 1 | $22 |
| 1 | Pour & Cure | 600 (10m) | 6 | pair | 1 | $22 |
| 2 | Sand & Polish | 1800 (30m) | 3 | pair | 1 | $22 |
| 3 | Assemble Hardware | 600 (10m) | 6 | pair | 1 | $18 |
| 4 | Package | 480 (8m) | 4 | pair | 1 | $15 |

**Materials (5):**

| # | Title | Bulk Cost | Qty | Unit | Units/Prod |
|---|-------|-----------|-----|------|------------|
| 0 | Epoxy Resin | $35 | 32 | oz | 1 |
| 1 | Resin Pigment | $14 | 120 | gram | 2 |
| 2 | Earring Hooks | $10 | 100 | pair | 1 |
| 3 | Backing Cards | $12 | 50 | card | 1 |
| 4 | Poly Bags | $6 | 200 | bag | 1 |

**Pricing:** Etsy, profitMargin: 0.40, percentSalesFromMarketing: 0.20
**Shared:** "Package" step (reuses existing entity)
**Showcases:** 5 steps, 5 materials, higher labor buffer (10%), highest profit margin

---

### Shared Item Overlap Summary

| Shared Entity | Type | Templates Using It |
|---------------|------|--------------------|
| "Package" | WorkStep | Woodworking, 3D Printing, Laser, Resin (4 of 5) |
| "Packaging" | Material | Woodworking, 3D Printing, Laser (3 of 5) |
| "Sandpaper Assortment" | Material | Woodworking, 3D Printing (2 of 5) |

---

## Step 3: Template Applier (`Engine/TemplateApplier.swift`)

Caseless `enum TemplateApplier` with one static function:

```swift
@MainActor
static func apply(_ template: ProductTemplate, to context: ModelContext) throws -> Product
```

**Algorithm:**
1. Create `Product` from template fields, insert into context
2. For each `WorkStepTemplate` (enumerated for `sortOrder`):
   - Query `FetchDescriptor<WorkStep>` with `#Predicate { $0.title == targetTitle }`
   - If found → reuse existing WorkStep
   - If not → create new WorkStep from template, insert
   - Create `ProductWorkStep` join model with template's `unitsRequiredPerProduct` and `laborRate`
   - Insert, append to `product.productWorkSteps` and `step.productWorkSteps`
3. For each `MaterialTemplate` (same dedup pattern):
   - Query by title, reuse or create
   - Create `ProductMaterial` join model, insert, append to both sides
4. For each `PricingTemplate`:
   - Convert `platformType` string to `PlatformType(rawValue:)`, skip if invalid
   - Create `ProductPricing`, insert
5. Return the new `Product`

No `context.save()` inside — SwiftData auto-saves. Tests call save explicitly.

---

## Step 4: Template Picker UI (`Views/Products/TemplatePickerView.swift`)

**Structure:** Sheet with `NavigationStack`.

```
NavigationStack
├── title: "Start from Template" (inline)
├── toolbar: Cancel button
└── ScrollView
    └── LazyVGrid (2 flexible columns)
        └── ForEach(ProductTemplates.all, id: \.id)
            └── TemplateCardView (tappable)
                ├── SF Symbol icon (36pt, accent color)
                ├── Title (sectionHeader, centered)
                └── Summary (gridCaption, secondary, 2-line)
```

- Cards use `.cardStyle()`, height `AppTheme.Sizing.gridCellHeight`
- Background: `.appBackground()`
- Callback: `onProductCreated: ((Product) -> Void)?`
- On tap: calls `TemplateApplier.apply()` → fires callback → dismisses

---

## Step 5: Modify ProductListView

### A. Toolbar "+" becomes a Menu
```swift
ToolbarItem(placement: .primaryAction) {
    Menu {
        Button { showingCreateForm = true } label: {
            Label("Blank Product", systemImage: "doc")
        }
        Button { showingTemplatePicker = true } label: {
            Label("From Template", systemImage: "doc.on.doc.fill")
        }
    } label: {
        Image(systemName: "plus")
    }
}
```

### B. Add template picker sheet
New `@State private var showingTemplatePicker = false`. Reuses existing `newlyCreatedProduct` + `onDismiss` navigation pattern:
```swift
.sheet(isPresented: $showingTemplatePicker, onDismiss: {
    if let product = newlyCreatedProduct {
        navigationPath.append(product)
        newlyCreatedProduct = nil
    }
}) {
    TemplatePickerView(onProductCreated: { product in
        newlyCreatedProduct = product
    })
}
```

### C. Update empty state
Change description to: `"Tap + to create a blank product or start from a template."`

---

## Step 6: Tests (`Epic4_5Tests.swift`)

14 tests using Swift Testing (`import Testing`, `@Test`, `#expect`):

**Template Data Integrity (3):**
1. All templates have non-empty titles, summaries, iconNames
2. All work steps have batchUnitsCompleted > 0, recordedTime >= 0, laborRate >= 0
3. All materials have bulkQuantity > 0, bulkCost >= 0

**Template Application (4):**
4. Woodworking template creates product with correct field values
5. Correct number of WorkSteps + ProductWorkStep join models with correct sortOrder
6. Correct number of Materials + ProductMaterial join models
7. ProductPricing created with correct platform type and fee values

**Buffers & Shipping (1):**
8. Candle template product has correct shipping (7.50), materialBuffer (0.10), laborBuffer (0.05)

**Deduplication (4):**
9. Same template twice → reuses WorkSteps (2 products, 8 joins, 4 steps)
10. Same template twice → reuses Materials (2 products, 8 joins, 4 materials)
11. Two templates with overlapping materials → "Packaging" + "Sandpaper Assortment" deduplicated (6 total, not 8)
12. Two templates with overlapping steps → "Package" deduplicated (7 total, not 8)

**All Templates (2):**
13. All 5 templates apply without error, 5 products created
14. Template pricing fees match template definition values exactly

---

## Implementation Order

1. `Engine/ProductTemplates.swift` — pure data, no dependencies
2. `Engine/TemplateApplier.swift` — depends on templates + models
3. `MakerMarginsTests/Epic4_5Tests.swift` — depends on both above
4. `Views/Products/TemplatePickerView.swift` — depends on templates + applier
5. Modify `Views/Products/ProductListView.swift` — depends on picker view

---

## Verification

1. **Unit tests:** All 14 tests in `Epic4_5Tests.swift` pass in CI
2. **Manual (simulator):** Products tab → "+" → "From Template" → Woodworking → verify 4 steps, 4 materials, $12 shipping, Etsy pricing ~$97
3. **Dedup check:** Apply Woodworking then 3D Printing → Materials library → one "Packaging" material, "Used by" shows both products
4. **Empty state:** Fresh install shows updated text mentioning templates
