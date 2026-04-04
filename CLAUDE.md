# MakerMargins — Shop Intelligence App
## Persistent Architecture & Engineering Reference

This file is the source of truth for Claude Code across all sessions. Update it as the project evolves.

---

## Project Overview

**App Name:** MakerMargins
**Purpose:** iOS app for makers (woodworkers, crafters, small-scale manufacturers) to track SKU-level labor and material costs, calculate true cost of goods sold, and generate data-driven retail pricing.

**Tech Stack**
- Language: Swift 6.0
- Framework: SwiftUI (Liquid Glass design system — iOS 26 native)
- Database: SwiftData
- Testing: Swift Testing framework (`import Testing`, `@Test` macros) — NOT XCTest/XCTestCase
- Target Platform: iOS
- Minimum Deployment Target: **iOS 26**
- Distribution: Single-user, local SwiftData only (no CloudKit sync)
- Currency: USD by default; EUR available via user setting. Format all monetary `Decimal` values through a shared `CurrencyFormatter` that respects the user's selection.

**Deployment Target Rationale**
iOS 26 is the minimum. The Liquid Glass design language is a first-class iOS 26 system behavior (materials, specular layering, adaptive chrome) — backporting it to earlier OS versions would require significant custom work that has no business value for a greenfield app. SwiftData's most stable relationship APIs also require iOS 17+, and iOS 26 gives us the full modern stack without workarounds.

---

## Development Roadmap

| Epic | Scope | Status |
|------|-------|--------|
| 0 | Infrastructure — Repo, SwiftData models, Navigation shell, Design Sprint, CI pipeline | **Complete** |
| 1 | Product & Category Management + E2E Tests | **Complete** |
| 2 | Labor Engine & Stopwatch + E2E Tests | **Complete** |
| 3 | Material Ledger & Costing + E2E Tests | **Complete** |
| 3.5 | Item vs Product Cost Separation + E2E Tests | **Complete** |
| 4 | Pricing Calculator & Platform Tabs + E2E Tests | **Complete** |
| 4.5 | Template Products + Bundled Images + E2E Tests | **Complete** |
| 5 | Batch Forecasting Calculator + E2E Tests | **Complete** |
| 6 | Portfolio Metrics & Product Comparison + E2E Tests | Pending |
| 7 | Production Readiness & App Store Launch | Pending |

---

## Core Schema (Source of Truth)

> **Important:** SwiftData auto-manages the primary key via `persistentModelID`. There is NO explicit `id: UUID` property on any model — do not add one.
> The `description` field from the original spec is named **`summary`** in Swift to avoid shadowing `NSObject.description`. Use `summary` in all code.

### Product
| Swift Property | Type | Notes |
|----------------|------|-------|
| title | String | |
| summary | String | Conceptual field name is "description" |
| image | Data? | Optional image blob |
| shippingCost | Decimal | Per-unit shipping cost |
| materialBuffer | Decimal | Fraction e.g. 0.10 = 10% |
| laborBuffer | Decimal | Fraction e.g. 0.05 = 5% |
| category | Category? | Many-to-one, optional |
| productWorkSteps | [ProductWorkStep] | One-to-many to join model, cascade delete (removes associations, NOT the shared WorkSteps) |
| productMaterials | [ProductMaterial] | One-to-many to join model, cascade delete (removes associations, NOT the shared Materials) |
| productPricings | [ProductPricing] | One-to-many, cascade delete. Up to 4 (one per PlatformType), created lazily. |

### Category
| Swift Property | Type | Notes |
|----------------|------|-------|
| name | String | |
| products | [Product] | One-to-many inverse; delete rule: nullify (products are NOT deleted) |

### WorkStep
WorkSteps are **shared entities** — they can be reused across multiple products via the `ProductWorkStep` join model. Editing a step from any context updates it everywhere.

| Swift Property | Type | Notes |
|----------------|------|-------|
| title | String | |
| summary | String | Conceptual field name is "description" |
| image | Data? | Optional |
| recordedTime | TimeInterval | Seconds — total time for the batch run. Set manually or via StopwatchView |
| batchUnitsCompleted | Decimal | Units produced in that batch. **Default: 1** (guards against division by zero) |
| unitName | String | e.g. "piece", "board". **Default: "unit"** |
| defaultUnitsPerProduct | Decimal | Default units per product, pre-fills join model. **Default: 1** |
| productWorkSteps | [ProductWorkStep] | One-to-many to join model, cascade delete (deleting a step removes all its associations) |

### ProductWorkStep
Join model enabling many-to-many between Product and WorkStep with per-product ordering and per-product cost settings.

| Swift Property | Type | Notes |
|----------------|------|-------|
| product | Product? | Many-to-one |
| workStep | WorkStep? | Many-to-one |
| sortOrder | Int | Per-product display order. **Default: 0** |
| unitsRequiredPerProduct | Decimal | Per-product override of units needed. **Default: 1** |
| laborRate | Decimal | $/hour, per-product context. Pre-filled from LaborRateManager.defaultRate. **Default: 0** |

### ProductMaterial
Join model enabling many-to-many between Product and Material with per-product ordering.

| Swift Property | Type | Notes |
|----------------|------|-------|
| product | Product? | Many-to-one |
| material | Material? | Many-to-one |
| sortOrder | Int | Per-product display order. **Default: 0** |

### Material
Materials are **shared entities** — they can be reused across multiple products via the `ProductMaterial` join model. Editing a material from any context updates it everywhere.

| Swift Property | Type | Notes |
|----------------|------|-------|
| title | String | |
| summary | String | Conceptual field name is "description" |
| image | Data? | Optional |
| link | String | Optional supplier URL. **Default: ""** |
| bulkCost | Decimal | Total cost of the bulk purchase |
| bulkQuantity | Decimal | Units in the bulk purchase. **Default: 1** (guards against division by zero) |
| unitName | String | e.g. "oz", "board-foot". **Default: "unit"** |
| unitsRequiredPerProduct | Decimal | Units consumed per product. **Default: 1** |
| productMaterials | [ProductMaterial] | One-to-many to join model, cascade delete (deleting a material removes all its associations) |

### PlatformFeeProfile
Single universal record storing user-configurable default pricing values. Managed in Settings. Created lazily on first access. Platform-imposed fees are hardcoded constants on `PlatformType` — only user-configurable values are persisted here.

| Swift Property | Type | Notes |
|----------------|------|-------|
| platformFee | Decimal | Default platform fee % (fraction). **Default: 0** |
| paymentProcessingFee | Decimal | Default payment processing fee % (fraction). **Default: 0** |
| marketingFee | Decimal | Default marketing fee rate (fraction). **Default: 0** |
| percentSalesFromMarketing | Decimal | Default fraction of sales from marketing/ads. **Default: 0** |
| profitMargin | Decimal | Default target profit margin (fraction). **Default: 0.30** |

> `PlatformType` is a `String`-backed `Codable` enum defined in `PlatformFeeProfile.swift`. Has an extension with locked fee constants (`lockedPlatformFee`, `lockedPaymentProcessingFee`, `lockedPaymentProcessingFixed`, `lockedMarketingFee`), editability flags, and display helpers (`platformFeeDisplay`, `paymentProcessingDisplay`, `marketingFeeDisplay`).

### ProductPricing
Per-product per-platform pricing overrides. Up to 4 per product (one per `PlatformType`). Created lazily from `PlatformFeeProfile` defaults when user first visits a platform tab.

| Swift Property | Type | Notes |
|----------------|------|-------|
| product | Product? | Many-to-one |
| platformType | PlatformType | Which platform these overrides are for |
| platformFee | Decimal | Platform fee % override (fraction). General only. **Default: 0** |
| paymentProcessingFee | Decimal | Payment processing fee % override (fraction). General only. **Default: 0** |
| marketingFee | Decimal | Marketing fee rate override (fraction). General/Shopify/Amazon. **Default: 0** |
| percentSalesFromMarketing | Decimal | Fraction of sales from marketing/ads. **Default: 0** |
| profitMargin | Decimal | Target profit margin (fraction). **Default: 0.30** |
| actualPrice | Decimal | What the user actually charges on this platform. **Default: 0** (not yet set) |
| actualShippingCharge | Decimal | What the customer pays for shipping on this platform. **Default: 0** (free shipping) |

---

## Calculation Logic (The Math)

All calculations are implemented in `Engine/CostingEngine.swift` — **not** as computed properties on the models. Models are pure data; CostingEngine is pure logic. `CostingEngine` is a caseless `enum` (pure namespace) with `static` functions. Labor calculations implemented (Epic 2); material calculations implemented (Epic 3).

Each function has a model-based overload (accepts `ProductWorkStep`/`Product`) and a raw-value overload (accepts `TimeInterval`/`Decimal` primitives) for real-time form previews before a model is saved.

```
// WorkStep level (item-level — no labor rate)
unitTime      = recordedTime / batchUnitsCompleted      // seconds per unit
unitTimeHours = unitTime / 3600                          // convert to hours (key output of a WorkStep)

// Product Labor (per ProductWorkStep — laborRate lives on the join model)
laborHoursPerProduct = unitTimeHours * unitsRequiredPerProduct
stepLaborCost        = laborHoursPerProduct * laborRate   // laborRate from ProductWorkStep

// Product total labor
totalLaborCost = sum of stepLaborCost across all WorkSteps

// Material level
materialUnitCost = bulkCost / bulkQuantity

// Product Material (per Material)
materialLineCost = materialUnitCost * unitsRequiredPerProduct

// Product total material
totalMaterialCost = sum of materialLineCost across all Materials

// Total Production Cost (per-section buffers — shipping is never buffered)
totalLaborCostBuffered    = totalLaborCost * (1 + laborBuffer)
totalMaterialCostBuffered = totalMaterialCost * (1 + materialBuffer)
totalProductionCost       = totalLaborCostBuffered + totalMaterialCostBuffered + shippingCost

// Target Retail Price (per platform — Epic 4)
// Locked fees come from PlatformType constants; user fees from ProductPricing.
// resolvedFees() centralises locked-vs-user logic.
effectiveMarketing    = marketingFee * percentSalesFromMarketing
totalPercentFees      = platformFee + paymentProcessingFee + effectiveMarketing
targetRetailPrice     = (totalProductionCost + paymentProcessingFixed) / (1 - (totalPercentFees + profitMargin))
// paymentProcessingFixed is always a locked constant from PlatformType (e.g. $0.25 for Etsy)
// Returns nil if denominator ≤ 0 (fees + margin ≥ 100%)
```

```

```
// Profit Analysis (per platform — Epic 4)
// Platform + processing fees apply to full customer payment; marketing on price only.
productionCostExShipping = totalLaborCostBuffered + totalMaterialCostBuffered
grossRevenue             = actualPrice + actualShippingCharge
totalSaleFees            = grossRevenue × (platformFee + paymentProcessingFee)
                         + actualPrice × effectiveMarketing + paymentProcessingFixed
actualProfit             = grossRevenue - totalSaleFees - productionCostExShipping - shippingCost
actualProfitMargin       = actualProfit / grossRevenue  // nil if grossRevenue = 0

// Earnings Metrics (solo-maker — "Your Earnings" in UI)
totalLaborHours          = sum of laborHoursPerProduct across all ProductWorkSteps
earningsPerSale          = actualProfit + totalLaborCostBuffered   // UI: "Your Earnings / Sale"
effectiveHourlyRate      = earningsPerSale / totalLaborHours       // nil if hours = 0; UI: "Effective Hourly Rate"
// actualProfit shown as "Margin After Costs" in UI breakdown (secondary, not hero)
```

```
// Batch Forecasting (per batch of N units — Epic 5)
batchStepHours         = laborHoursPerProduct * batchSize
batchLaborHours        = totalLaborHours * batchSize
batchMaterialUnits     = unitsRequiredPerProduct * batchSize
batchMaterialLineCost  = materialLineCost * batchSize
bulkPurchasesNeeded    = ceil(batchMaterialUnits / bulkQuantity)   // returns (purchases, totalBulkUnits, leftover)
batchPurchaseCost      = bulkPurchasesNeeded.purchases * bulkCost
batchProductionCost    = totalProductionCost * batchSize
batchCostPerUnit       = batchProductionCost / batchSize           // identity check — equals totalProductionCost
batchRevenue           = (actualPrice + actualShippingCharge) * batchSize
batchTotalFees         = totalSaleFees * batchSize                 // fixed fees apply per transaction
batchProfit            = actualProfit * batchSize
```

**Division-by-zero guards:** `batchUnitsCompleted` and `bulkQuantity` both default to 1. CostingEngine must still guard against zero before dividing. `targetRetailPrice` returns `nil` when the denominator is not positive. `actualProfitMargin` returns `nil` when gross revenue is zero. `bulkPurchasesNeeded` returns `(0, 0, 0)` when `bulkQuantity` is zero or negative. `batchCostPerUnit` returns `0` when `batchSize` is zero.

---

## Directory Layout

```
MakerMargins/                              ← repo root
├── CLAUDE.md                              ← this file
├── project.yml                            ← XcodeGen spec (generates .xcodeproj)
├── .gitignore                             ← excludes .xcodeproj, DerivedData, build/
├── .github/
│   └── workflows/
│       └── ci.yml                         ← GitHub Actions: XcodeGen → build → test
│
├── MakerMargins/                          ← main app target
│   ├── MakerMarginsApp.swift              ← @main entry point, ModelContainer with all 8 models
│   ├── ContentView.swift                  ← 4-tab TabView shell (Products, Labor, Materials, Settings)
│   │
│   ├── Models/                            ← SwiftData @Model types (all implemented)
│   │   ├── Product.swift
│   │   ├── Category.swift
│   │   ├── WorkStep.swift                 ← shared entity (many-to-many via ProductWorkStep)
│   │   ├── ProductWorkStep.swift          ← join model: Product ↔ WorkStep with sortOrder
│   │   ├── Material.swift                 ← shared entity (many-to-many via ProductMaterial)
│   │   ├── ProductMaterial.swift          ← join model: Product ↔ Material with sortOrder
│   │   ├── PlatformFeeProfile.swift       ← universal pricing defaults + PlatformType enum & extension
│   │   └── ProductPricing.swift          ← join model: Product ↔ PlatformType with pricing overrides
│   │
│   ├── Assets.xcassets/                   ← Asset catalog: AppIcon + 42 template image sets (Epic 4.5)
│   │
│   ├── Engine/                            ← calculation, formatting & app-level managers
│   │   ├── CostingEngine.swift            ← labor + material + target price + batch forecasting calculations (Epic 2-5)
│   │   ├── CurrencyFormatter.swift        ← implemented Epic 1
│   │   ├── AppearanceManager.swift        ← System/Light/Dark toggle, UserDefaults-persisted
│   │   ├── LaborRateManager.swift         ← default hourly rate, UserDefaults-persisted (Epic 2)
│   │   ├── ProductTemplates.swift         ← pure-data template definitions for 5 maker workflows (Epic 4.5)
│   │   └── TemplateApplier.swift          ← hydrates templates into SwiftData entities with dedup (Epic 4.5)
│   │
│   ├── Theme/                             ← design system tokens and reusable view modifiers
│   │   ├── AppTheme.swift                 ← colors (surface, surfaceElevated, accent, categoryBadge, tabTint, cardBorder, etc.), spacing, corner radii, typography, sizing
│   │   └── ViewModifiers.swift            ← .cardStyle(), .appBackground(), .editableFieldStyle(), CurrencyInputField, PercentageInputField, PercentageFormat, PlaceholderImageView, WorkStepThumbnailView, MaterialThumbnailView
│   │
│   └── Views/                             ← SwiftUI views, grouped by feature
│       ├── Products/                      ← Tab 1 root + all product-owned views
│       │   ├── ProductListView.swift      ← Tab 1 root (NavigationStack), product duplication, template picker menu — Epic 1+4.5
│       │   ├── ProductDetailView.swift    ← pinned header + segmented sub-tabs (Build/Price/Forecast) — Epic 1+2+4
│       │   ├── ProductFormView.swift      ← create/edit sheet, inline category creation — Epic 1
│       │   ├── ProductCostSummaryCard.swift ← cost breakdown card (labor + materials live) — Epic 2+3
│       │   ├── PricingCalculatorView.swift  ← target price calculator + profit analysis, rendered in Price sub-tab — Epic 4
│       │   ├── TemplatePickerView.swift     ← sheet: 2-column grid of template cards — Epic 4.5
│       │   └── BatchForecastView.swift      ← batch forecasting calculator in Forecast sub-tab — Epic 5
│       ├── Workshop/                      ← Tab 2 (Labor): shared step library
│       │   └── WorkshopView.swift         ← searchable list of all WorkSteps, titled "Labor" — Epic 2
│       ├── Labor/
│       │   ├── WorkStepListView.swift     ← inline step list in ProductDetailView — Epic 2
│       │   ├── WorkStepDetailView.swift   ← pushed from Products or Workshop tab — Epic 2
│       │   ├── WorkStepFormView.swift     ← create/edit sheet — Epic 2
│       │   └── StopwatchView.swift        ← fullScreenCover from detail/form — Epic 2
│       ├── Materials/
│       │   ├── MaterialsLibraryView.swift ← Tab 3 root: shared materials library — Epic 3
│       │   ├── MaterialListView.swift     ← inline material list in ProductDetailView — Epic 3
│       │   ├── MaterialDetailView.swift   ← pushed from Products or Materials tab — Epic 3
│       │   └── MaterialFormView.swift     ← create/edit sheet — Epic 3
│       ├── Categories/
│       │   ├── CategoryListView.swift     ← legacy, no longer navigated to from Settings — Epic 1
│       │   └── CategoryFormView.swift     ← legacy, categories now created inline in ProductFormView — Epic 1
│       └── Settings/                      ← Tab 4 root + config views
│           ├── SettingsView.swift         ← Tab 4 root: currency, appearance, labor rate, platform pricing — Epic 1+2+4
│           └── PlatformPricingDefaultFormView.swift ← single universal pricing defaults form — Epic 4
│
├── MakerMarginsTests/                     ← Swift Testing suite (import Testing, @Test)
│   ├── Epic0Tests.swift                   ← Complete: test harness smoke test
│   ├── Epic1Tests.swift                   ← Complete: Product/Category CRUD, cascade, CurrencyFormatter, product duplication (13 tests)
│   ├── Epic2Tests.swift                   ← Complete: WorkStep/join CRUD, CostingEngine, reorder, LaborRateManager (12 tests)
│   ├── Epic3Tests.swift                   ← Complete: Material/join CRUD, CostingEngine material calcs, per-section buffers, duplication (12 tests)
│   ├── Epic3_5Tests.swift                 ← Complete: Item/product separation, laborRate on join, per-product independence, laborHoursPerProduct (12 tests)
│   ├── Epic4Tests.swift                   ← Complete: PlatformFeeProfile/ProductPricing CRUD, PlatformType constants + display helpers, targetRetailPrice calcs, duplication (20 tests)
│   ├── Epic4_5Tests.swift                 ← Complete: Template data integrity, TemplateApplier entity creation, title-based deduplication (14 tests)
│   └── Epic5Tests.swift                   ← Complete: Batch forecasting calculations, bulk purchase planning, revenue projections (22 tests)
│
└── MakerMarginsUITests/                   ← UI automation (XCUITest)
    └── MakerMarginsUITests.swift          ← STUB
```

---

## Navigation Structure

**4-Tab TabView.** ContentView owns only the TabView — no state, no queries. Each tab root owns its own `NavigationStack`. Tab bar is tinted sage green (`AppTheme.Colors.tabTint`).

| Tab | Root View | SF Symbol |
|-----|-----------|-----------|
| 1 | `ProductListView` | `square.grid.2x2` |
| 2 | `WorkshopView` | `hammer` |
| 3 | `MaterialsLibraryView` | `shippingbox` |
| 4 | `SettingsView` | `gearshape` |

### Tab 1 — Products (primary workspace)
```
ProductListView                            [ROOT — context menu: Duplicate, Delete]
└── [push] ProductDetailView               [Level 1 — pinned header + segmented sub-tabs]
    │   Pinned Header: category badge, description, sub-tab picker
    │   Sub-tabs: Build | Price | Forecast
    │
    │   Build Tab:
    │       Product image + header details
    │       Cost Summary (ProductCostSummaryCard)
    │       Labor Workflow section (inline WorkStepListView — VStack, not List)
    │       Materials section (inline MaterialListView content)
    │       Shipping section (inline GroupBox with editable Average Shipping Cost)
    │
    │   Price Tab:
    │       Pricing Calculator (PricingCalculatorView — platform tabs, target price + profit analysis)
    │
    │   Forecast Tab:
    │       Batch Forecast (BatchForecastView — Epic 5 stub)
    │
    ├── [push] WorkStepDetailView          [Level 2 — from Build tab; edit in toolbar; "Remove from Product" button in product context]
    │   └── [fullScreenCover] StopwatchView  [Level 3 — MAX DEPTH, pause/resume]
    ├── [push] MaterialDetailView          [Level 2 — from Build tab; edit in toolbar; "Remove from Product" button in product context]
    │   └── [sheet] MaterialFormView       [edit]
    ├── [sheet] ProductFormView            [create / edit, inline category creation]
    ├── [sheet] WorkStepFormView           [create / edit, FocusState, time validation]
    └── [sheet] MaterialFormView           [create / edit, FocusState, cost validation]
```

### Tab 2 — Labor (shared step library, speed to stopwatch)
```
WorkshopView                              [ROOT — titled "Labor", searchable list of all shared WorkSteps]
└── [push] WorkStepDetailView             [Level 1 — edit/stopwatch surfaced in toolbar]
    └── [fullScreenCover] StopwatchView   [Level 2 — pause/resume]
```
**Stopwatch tap count:** 2 taps from Labor tab. Fastest path for a maker mid-production.
**Step library:** Steps are shared entities. Shows all steps with product names in "Used by" text and cost. New steps can be created here (standalone) or from a product's detail view.

### Tab 3 — Materials (shared material library)
```
MaterialsLibraryView                      [ROOT — titled "Materials", searchable list of all shared Materials]
└── [push] MaterialDetailView             [Level 1 — edit/delete in toolbar]
    └── [sheet] MaterialFormView          [edit]
```
**Material library:** Materials are shared entities. Shows all materials with product names in "Used by" text and cost. New materials can be created here (standalone) or from a product's detail view.

### Tab 4 — Settings (one-time config)
```
SettingsView                              [ROOT — currency, appearance, labor rate, pricing defaults]
└── [push] PlatformPricingDefaultFormView [Level 1 — single universal pricing defaults form]
```
**Note:** Category management has moved to inline creation within `ProductFormView`. The Settings → Categories navigation link has been removed.

---

## Epic 1 — Acceptance Criteria ✅

**Product CRUD**
- [x] User can create a Product (title, summary, shippingCost, materialBuffer, laborBuffer, optional category)
- [x] User can view a list of all Products on `ProductListView`
- [x] User can tap a Product to open `ProductDetailView`
- [x] User can edit a Product via `ProductFormView`
- [x] User can delete a Product (with confirmation); its associations and Materials are cascade-deleted

**Category CRUD**
- [x] User can create Categories inline from the product form's category picker
- [x] User can assign a Category when creating/editing a Product
- [x] Deleting a Category does NOT delete its Products (products become uncategorised)
- [x] Category management removed from Settings (inline-only workflow)

**Currency Setting**
- [x] `SettingsView` has a USD / EUR toggle
- [x] `CurrencyFormatter` is implemented and used by all monetary display fields
- [x] Switching currency re-renders all visible monetary values

**Appearance & Theme**
- [x] `AppTheme.Colors.surface` warm background applied to all page-level views
- [x] `AppTheme.Colors.surfaceElevated` updated for visible card contrast against surface
- [x] `SettingsView` has a System / Light / Dark appearance picker
- [x] `AppearanceManager` persists choice and applies `.preferredColorScheme()` at app root

**Product Duplication**
- [x] User can duplicate a Product via context menu (long press) in list or grid
- [x] Duplication copies all metadata, re-links shared WorkSteps, re-links shared Materials
- [x] Duplicated product title gets " (Copy)" suffix

**E2E Tests (Epic1Tests.swift)**
- [x] Test: create a Product and fetch it back via SwiftData
- [x] Test: create a Category, assign it to a Product, verify the relationship
- [x] Test: delete a Category, verify the Product's category becomes nil
- [x] Test: delete a Product, verify its associations are deleted but shared WorkSteps and Materials survive
- [x] Test: CurrencyFormatter formats Decimal correctly for USD and EUR
- [x] Test: product duplication copies metadata, re-links shared steps, re-links shared materials

---

## Epic 2 — Acceptance Criteria ✅

**WorkStep CRUD**
- [x] User can create a WorkStep from a product's detail view (title, summary, image, time, batch units, unit name, units per product, labor rate)
- [x] User can edit a WorkStep; changes propagate to all products using it
- [x] User can delete a WorkStep from its detail view; all associations are cascade-deleted
- [x] User can remove a WorkStep from a product (removes association, step survives in library)

**Shared Steps**
- [x] Steps are reusable across products via `ProductWorkStep` join model
- [x] User can add existing steps to a product via multi-select picker (checkmark toggles, batch add)
- [x] WorkStepDetailView shows "Used By" section listing all products with thumbnails
- [x] Editing a step from any product context updates it everywhere
- [x] "Used by" text shows product names (e.g. "Used by Standard Bagel Board + 2 others")

**Reorder Steps**
- [x] User can reorder steps within a product's workflow via "Reorder" toggle button (up/down arrows)
- [x] `sortOrder` persists across app launches

**Stopwatch**
- [x] User can open a full-screen stopwatch from WorkStepDetailView or WorkStepFormView
- [x] Stopwatch displays step title context ("Timing: Step Name")
- [x] Start / Pause / Resume / Save / Discard / Re-record flow (pause/resume with accumulated time)
- [x] Saving writes the elapsed time to the step's `recordedTime`
- [x] User can still manually edit time after using the stopwatch

**Cost Calculations**
- [x] `CostingEngine` implements labor calculations (unitTimeHours, stepLaborCost, totalLaborCost, totalProductionCost)
- [x] Real-time calculated preview in WorkStepFormView as user fills fields
- [x] `ProductCostSummaryCard` shows live labor cost and total production cost
- [x] Derived/calculated values (time per unit, time per product, labor cost) displayed in accent color to distinguish from user-entered values

**Default Labor Rate**
- [x] `SettingsView` has a "Default Hourly Rate" field with `/hr` suffix
- [x] `LaborRateManager` persists default rate to UserDefaults
- [x] New steps pre-fill with the default rate; user can override per-step

**Labor Tab (formerly Workshop)**
- [x] Tab 2 shows all WorkSteps as a searchable step library, titled "Labor"
- [x] Each row shows title, product names in "Used by" text, and step labor cost
- [x] User can create standalone steps (not linked to a product) from Labor tab
- [x] Tapping a step pushes WorkStepDetailView with edit and stopwatch buttons surfaced in toolbar

**E2E Tests (Epic2Tests.swift)**
- [x] Test: create a WorkStep, persist, fetch, verify all properties
- [x] Test: create ProductWorkStep association, verify sortOrder
- [x] Test: shared step across two products, edit propagates to both
- [x] Test: reorder steps, verify sortOrder updates correctly
- [x] Test: delete product preserves shared WorkStep
- [x] Test: delete WorkStep cascades to associations
- [x] Test: CostingEngine calculations (unitTimeHours, zero guard, stepLaborCost, totalLaborCost, totalProductionCost)
- [x] Test: LaborRateManager UserDefaults round-trip

---

## Epic 3 — Acceptance Criteria ✅

**Material CRUD**
- [x] User can create a Material from a product's detail view (title, summary, image, link, bulk cost, bulk quantity, unit name, units per product)
- [x] User can edit a Material; changes propagate to all products using it
- [x] User can delete a Material from its detail view; all associations are cascade-deleted
- [x] User can remove a Material from a product (removes association, material survives in library)

**Shared Materials**
- [x] Materials are reusable across products via `ProductMaterial` join model
- [x] User can add existing materials to a product via multi-select picker (checkmark toggles, batch add)
- [x] MaterialDetailView shows "Used By" section listing all products with thumbnails
- [x] Editing a material from any product context updates it everywhere
- [x] "Used by" text shows product names (e.g. "Used by Walnut Board + 2 others")

**Reorder Materials**
- [x] User can reorder materials within a product via "Reorder" toggle button (up/down arrows)
- [x] `sortOrder` persists across app launches

**Cost Calculations**
- [x] `CostingEngine` implements material calculations (materialUnitCost, materialLineCost, totalMaterialCost)
- [x] Real-time calculated preview in MaterialFormView as user fills fields (cost per unit, cost per product)
- [x] `ProductCostSummaryCard` shows live material cost and total production cost
- [x] Derived/calculated values displayed in accent color to distinguish from user-entered values

**Per-Section Buffers**
- [x] Labor Cost Buffer % editable inline in WorkStepListView section
- [x] Material Cost Buffer % editable inline in MaterialListView section
- [x] Buffer sections include helper text explaining the percentage
- [x] "Total after buffer" shown below each buffer input
- [x] `totalProductionCost` uses per-section formula: `labor × (1 + laborBuffer) + material × (1 + materialBuffer) + shipping`

**Materials Tab**
- [x] Tab 3 shows all Materials as a searchable material library, titled "Materials"
- [x] Each row shows title, product names in "Used by" text, and material line cost
- [x] User can create standalone materials (not linked to a product) from Materials tab
- [x] Tapping a material pushes MaterialDetailView with edit and delete buttons in toolbar

**Material Detail**
- [x] MaterialDetailView shows header (image/placeholder, summary, tappable supplier link)
- [x] Purchase GroupBox shows bulk cost, quantity, unit name, units per product with dynamic labels
- [x] Cost GroupBox shows derived cost per unit and cost per product in accent color

**E2E Tests (Epic3Tests.swift)**
- [x] Test: create a Material, persist, fetch, verify all properties
- [x] Test: create ProductMaterial association, verify sortOrder
- [x] Test: shared material across two products, edit propagates to both
- [x] Test: reorder materials, verify sortOrder updates correctly
- [x] Test: delete product preserves shared Material
- [x] Test: delete Material cascades to associations
- [x] Test: CostingEngine calculations (materialUnitCost, zero guard, materialLineCost, totalMaterialCost, totalProductionCost with per-section buffers)
- [x] Test: product duplication re-links shared materials

---

## Epic 3.5 — Acceptance Criteria ✅

**Item vs Product Separation — Core Principle: "One Item, One Number"**
- WorkStep → Hours/Unit (item-level); Material → Cost/Unit (item-level)
- Labor rate, units per product, and derived costs are product-level (on join models)

**Schema Migration**
- [x] `laborRate` moved from WorkStep to ProductWorkStep join model
- [x] ProductWorkStep.laborRate defaults from LaborRateManager when creating associations
- [x] WorkStep no longer has a laborRate property

**WorkStep Form Simplification**
- [x] Form fields: image, title, description, time (h/m/s + stopwatch), batch units, unit name — only
- [x] No labor rate or units per product fields on the form
- [x] Hours/Unit displayed as hero preview value (accent, large font)

**Material Form Simplification**
- [x] Form fields: image, title, description, link, bulk cost, bulk quantity, unit name — only
- [x] No units per product field on the form
- [x] Cost/Unit displayed as hero preview value (accent, large font)

**WorkStep Detail View — Two-Zone Layout**
- [x] Step Info section (always shown): recorded time, batch units, time per unit, Hours/Unit hero
- [x] Product Settings section (product context only): editable labor rate, editable units per product
- [x] Calculated Labor Hrs/Product and Labor Cost/Product update in real-time
- [x] Changes save immediately to ProductWorkStep join model

**Material Detail View — Two-Zone Layout**
- [x] Material Info section (always shown): bulk cost, quantity, unit name, Cost/Unit hero
- [x] Product Settings section (product context only): editable units per product
- [x] Calculated Material Cost/Product updates in real-time
- [x] Changes save immediately to ProductMaterial join model

**Library Tab Updates**
- [x] Labor tab rows show Hours/Unit (item-level metric, not cost)
- [x] Materials tab rows show Cost/Unit (item-level metric, not line cost)

**Product Duplication**
- [x] Duplicated products copy laborRate from ProductWorkStep join models

**CostingEngine**
- [x] `stepLaborCost(step:)` removed — no labor rate on step
- [x] `stepLaborCost(link:)` reads laborRate from ProductWorkStep
- [x] `laborHoursPerProduct(link:)` and raw-value overload added
- [x] All product-level aggregate functions use join model data

**E2E Tests (Epic3_5Tests.swift)**
- [x] Test: ProductWorkStep stores and persists laborRate
- [x] Test: ProductWorkStep laborRate defaults to zero
- [x] Test: per-product laborRate independence (same step, different rates)
- [x] Test: per-product unitsRequiredPerProduct independence
- [x] Test: laborHoursPerProduct calculation (known values, zero guard, model overload)
- [x] Test: stepLaborCost uses link.laborRate, not step-level rate
- [x] Test: same step, different rates → different costs
- [x] Test: product duplication copies laborRate
- [x] Test: unitTimeHours is purely item-level
- [x] Test: materialUnitCost is purely item-level

---

## Epic 4 — Acceptance Criteria ✅

**PlatformFeeProfile (Universal Defaults)**
- [x] Single universal record storing default pricing values (no platformType)
- [x] Stores: platformFee, paymentProcessingFee, marketingFee, percentSalesFromMarketing, profitMargin
- [x] Created lazily on first access in Settings or calculator

**PlatformType Constants**
- [x] Locked fee constants: `lockedPlatformFee`, `lockedPaymentProcessingFee`, `lockedPaymentProcessingFixed`, `lockedMarketingFee`
- [x] Etsy: 6.5% platform + 3% processing + $0.25 fixed + 15% marketing (all locked)
- [x] Shopify: 0% platform + 2.9% processing + $0.30 fixed (locked), marketing editable
- [x] Amazon: 15% platform + 0% processing (locked), marketing editable
- [x] General: all nil/editable, no fixed fees
- [x] Editability flags: isPlatformFeeEditable, isPaymentProcessingFeeEditable, isMarketingFeeEditable
- [x] Display helpers: platformFeeDisplay, paymentProcessingDisplay (e.g. "3% + $0.25"), marketingFeeDisplay

**ProductPricing (Per-Product Overrides)**
- [x] Per-product per-platform pricing overrides (up to 4 per product)
- [x] Created lazily from PlatformFeeProfile defaults when user first visits a platform tab
- [x] Product cascade-deletes its ProductPricing entries

**CostingEngine — Target Price**
- [x] `effectiveMarketingRate` = marketingFee × percentSalesFromMarketing
- [x] `resolvedFees` centralises locked-vs-user fee resolution, returns 6-tuple including paymentProcessingFixed
- [x] `targetRetailPrice` raw-value + model overloads with split platformFee/paymentProcessingFee/paymentProcessingFixed, returns nil when fees + margin ≥ 100%

**PricingCalculatorView (Inline in ProductDetailView)**
- [x] Segmented platform picker (General | Etsy | Shopify | Amazon)
- [x] Consistent section layout across all tabs: Production Costs, Marketing and Fees, Profit Margin, Target Price
- [x] Production Costs sub-section shows Material Cost + Labor Cost + Shipping Cost + Total
- [x] Marketing and Fees sub-section: Platform Fee, Payment Processing, Marketing Fees, % Sales from Ads
- [x] General tab: all fee fields editable (percentages only, no fixed fees)
- [x] Etsy tab: all 3 fee rows locked (6.5%, "3% + $0.25", 15%)
- [x] Shopify/Amazon tabs: Platform Fee + Processing locked, Marketing editable
- [x] Locked fees displayed as text in tertiary color; editable fields use PercentageInputField
- [x] Target Price hero output (bold, large, accent) or "— (fees too high)" warning
- [x] Empty-state hint when production cost is $0
- [x] Subtle pricingSurface background to distinguish from product-building sections
- [x] Section footer explaining the calculator
- [x] Per-product overrides persist across app launches

**Settings — Pricing Defaults**
- [x] SettingsView "Selling" section with icon + footer, pushes directly to PlatformPricingDefaultFormView
- [x] Single universal form with 5 fields: Platform Fee, Payment Processing, Marketing Fee, % Sales from Ads, Profit Margin
- [x] Defaults pre-fill editable fields across all platform tabs (locked fees not affected)
- [x] Changes save immediately; footer explains defaults behavior

**Product Duplication**
- [x] Duplicated products copy ProductPricing overrides

**Shared Components**
- [x] PercentageFormat (toDisplay/fromDisplay) in ViewModifiers.swift
- [x] PercentageInputField reusable component in ViewModifiers.swift

**E2E Tests (Epic4Tests.swift)**
- [x] Test: PlatformFeeProfile create + fetch all fields
- [x] Test: PlatformFeeProfile defaults are correct
- [x] Test: ProductPricing create + fetch with product relationship
- [x] Test: delete Product cascades ProductPricing, PlatformFeeProfile survives
- [x] Test: per-platform pricing independence (same product, two platforms)
- [x] Test: Etsy locked fees correct (platformFee, processingFee, processingFixed, marketingFee)
- [x] Test: Shopify locked fees correct
- [x] Test: Amazon locked fees correct
- [x] Test: General has no locked fees
- [x] Test: editability flags correct per platform
- [x] Test: display helpers format locked fees correctly (e.g. "3% + $0.25")
- [x] Test: effectiveMarketingRate calculation
- [x] Test: targetRetailPrice General known inputs
- [x] Test: targetRetailPrice Etsy with locked fees + marketing frequency
- [x] Test: targetRetailPrice returns nil when fees + margin ≥ 100%
- [x] Test: resolvedFees applies locked constants for Etsy
- [x] Test: resolvedFees uses user values for General
- [x] Test: product duplication copies ProductPricing
- [x] Test: product duplication with no pricing overrides
- [x] Test: targetRetailPrice model overload matches raw-value overload

**Profit Analysis (Inline in PricingCalculatorView)**
- [x] "Profit Analysis" GroupBox below Target Price Calculator, same pricingSurface background
- [x] Selling Price and Shipping Charge currency inputs per platform
- [x] "Use Target Price" button pre-fills from computed target price
- [x] Breakdown section: Revenue, Platform Fees, Processing Fees, Marketing Fees, Production Cost, Shipping Expense
- [x] Fee rows hidden when amount is zero
- [x] Your Earnings / Sale hero (green positive, red negative) — single clear answer
- [x] Effective Hourly Rate in hero card (shown when totalLaborHours > 0)
- [x] Margin After Costs + Your Labor breakdown below hero (shown when labor > 0, secondary styling)
- [x] Profit Margin percentage display (secondary styling)
- [x] Total Fees percentage subtotal row in Marketing and Fees section
- [x] Shipping absorbed callout when charging $0 but shipping costs exist
- [x] Zero production cost warning in breakdown
- [x] Per-product per-platform actual pricing persists across app launches

**Template Actual Pricing**
- [x] PricingTemplate includes actualPrice and actualShippingCharge
- [x] All 5 templates have realistic actual prices (below target, varied shipping strategies)
- [x] TemplateApplier passes actual pricing fields through to ProductPricing

**E2E Tests (Profit Analysis — Epic4Tests.swift + Epic4_5Tests.swift)**
- [x] Test: totalSaleFees Etsy with shipping (fees on price+shipping, marketing on price only)
- [x] Test: totalSaleFees zero shipping
- [x] Test: actualProfit positive, negative, and free-shipping-absorbed scenarios
- [x] Test: actualProfitMargin nil for zero revenue, correct for known values
- [x] Test: productionCostExShipping equals totalProductionCost minus shipping
- [x] Test: totalLaborHours sums across work steps
- [x] Test: totalLaborHours returns 0 for no steps
- [x] Test: takeHomePerHour raw-value known values
- [x] Test: takeHomePerHour nil for zero hours
- [x] Test: takeHomePerHour model overload matches raw-value
- [x] Test: ProductPricing CRUD with actualPrice and actualShippingCharge
- [x] Test: Duplication copies actual pricing fields
- [x] Test: Template PricingTemplate has actual prices > 0
- [x] Test: TemplateApplier creates pricing with actual fields

---

## Epic 4.5 — Acceptance Criteria ✅

**Template Data Layer**
- [x] `ProductTemplates.swift` defines 5 maker workflow templates as pure Swift structs (no SwiftData dependency)
- [x] Template structs (`WorkStepTemplate`, `MaterialTemplate`, `PricingTemplate`, `ProductTemplate`) mirror model initializer signatures
- [x] Each template includes: product metadata (title, SKU, summary, image), 4–5 work steps, 3–5 materials, Etsy pricing, shipping, buffers
- [x] Templates: Woodworking, 3D Printing, Laser Engraving, Candle Making, Resin Art
- [x] Shared items have identical entity-level fields across templates for clean dedup

**Template Application with Deduplication**
- [x] `TemplateApplier.apply(_:to:)` creates Product + all linked entities in one call
- [x] WorkSteps deduplicated by title — existing step reused, only new join model created
- [x] Materials deduplicated by title — same pattern as WorkSteps
- [x] Shared "Package" step reused across 4 templates; "Packaging" and "Sandpaper Assortment" materials shared across templates
- [x] ProductPricing created from template with correct platform type and fee values
- [x] Returns the new Product for post-creation navigation

**Template Picker UI**
- [x] `TemplatePickerView` presented as sheet from ProductListView
- [x] 2-column grid of template cards with SF Symbol icon, title, summary
- [x] Cards use `.cardStyle()` and `AppTheme` tokens throughout
- [x] Tapping a card applies template, fires callback, dismisses sheet

**ProductListView Integration**
- [x] Toolbar "+" button is now a Menu with "Blank Product" and "From Template" options
- [x] Template picker sheet uses same `newlyCreatedProduct` + `onDismiss` navigation pattern as create form
- [x] Empty state text updated to mention templates

**Bundled Template Images**
- [x] `Assets.xcassets` created with AppIcon set + 42 template image sets
- [x] All 5 products, 18 unique work steps, and 19 unique materials have bundled images
- [x] `TemplateApplier` loads images via `UIImage(named:)?.jpegData()`, returns nil for empty names
- [x] Images are compiled into the app binary — available offline on first launch

**Template Variety (showcases app features)**
- [x] Labor rates range from $3/hr (machine time) to $30/hr (design skill)
- [x] Batch sizes range from 1 (solo) to 8 (candle batches)
- [x] Material buffers: 5–10%; Labor buffers: 5–10%
- [x] Profit margins: 30–40% across templates
- [x] Each template has a unique SKU (TMPL-WOOD, TMPL-3DP, TMPL-LASER, TMPL-CANDLE, TMPL-RESIN)

**E2E Tests (Epic4_5Tests.swift)**
- [x] Test: all templates have non-empty titles, summaries, icon names
- [x] Test: all work steps have valid batch data (batchUnitsCompleted > 0)
- [x] Test: all materials have valid bulk quantities (bulkQuantity > 0)
- [x] Test: applying woodworking template creates product with correct fields
- [x] Test: correct work steps and join models with sortOrder and laborRate
- [x] Test: correct materials and join models with sortOrder and unitsRequired
- [x] Test: ProductPricing created with correct Etsy platform and fee values
- [x] Test: candle template has correct shipping, material buffer, labor buffer
- [x] Test: same template twice reuses WorkSteps (4 entities, 8 joins)
- [x] Test: same template twice reuses Materials (4 entities, 8 joins)
- [x] Test: two templates with overlapping materials deduplicate correctly (6 not 8)
- [x] Test: two templates with overlapping steps deduplicate Package step (7 not 8)
- [x] Test: all 5 templates apply without error
- [x] Test: 3D printing template pricing fees match definition

## Epic 5 — Acceptance Criteria ✅

**CostingEngine — Batch Forecasting Functions**
- [x] `batchStepHours` model + raw-value overloads: labor hours per step × batch size
- [x] `batchLaborHours` model + raw-value overloads: total labor hours × batch size
- [x] `batchMaterialUnits` model + raw-value overloads: units per product × batch size
- [x] `batchMaterialLineCost` model + raw-value overloads: material line cost × batch size
- [x] `bulkPurchasesNeeded`: ceiling division with (purchases, totalBulkUnits, leftover) tuple; zero-guard on bulkQuantity
- [x] `batchPurchaseCost`: purchases × bulk cost
- [x] `batchProductionCost` model + raw-value overloads: production cost × batch size
- [x] `batchCostPerUnit`: batch cost / batch size; zero-guard on batchSize
- [x] `batchRevenue`: (actualPrice + actualShippingCharge) × batch size
- [x] `batchTotalFees`: per-sale fees × batch size (fixed fees per transaction)
- [x] `batchProfit`: per-sale profit × batch size
- [x] `formatHoursReadable`: Decimal hours → "Xh Ym" string (drops seconds)

**BatchForecastView (Forecast Sub-Tab)**
- [x] Batch size input with +/- buttons, editable text field, quick-select chips (5/10/25/50/100)
- [x] Batch size defaults to 10; session state only (not persisted)
- [x] Labor Time Forecast section: per-step hours breakdown (hrs/ea + batch total), total hero with decimal + human-readable "Xh Ym"
- [x] Material Shopping List section: units needed per material, "Buy X × [bulkQty] [unitName]" purchase recommendations, leftover tracking
- [x] Shopping list summary: material cost (buffered) vs total purchase cost, surplus explanation note
- [x] ~~Batch Cost Summary section~~ — removed (redundant with Revenue Forecast breakdown)
- [x] Revenue Forecast section: revenue/fees/production cost breakdown, batch earnings hero (green/red), earnings/unit, effective hourly rate, margin after costs
- [x] Revenue section only shown when ProductPricing with actualPrice > 0 exists
- [x] Pricing hint when no actual prices set, pointing to Price tab
- [x] Empty product state with ContentUnavailableView pointing to Build tab
- [x] All sections use existing UI components: CalculatorSectionHeader, DetailRow, heroCardStyle, sectionGroupStyle, pricingSurface
- [x] All monetary values formatted through CurrencyFormatter

**E2E Tests (Epic5Tests.swift)**
- [x] Test: batchStepHours raw-value multiplies by batch size
- [x] Test: batchLaborHours sums all steps and multiplies by batch size
- [x] Test: batchLaborHours raw-value overload matches model overload
- [x] Test: batchLaborHours returns zero when step has zero recorded time
- [x] Test: formatHoursReadable formats various hour values correctly (0h 0m, 0h 30m, 4h 45m, 25h 30m, 7h 30m, 12h 30m)
- [x] Test: batchMaterialUnits multiplies units per product by batch size
- [x] Test: batchMaterialLineCost multiplies line cost by batch size
- [x] Test: bulkPurchasesNeeded exact fit (zero leftover)
- [x] Test: bulkPurchasesNeeded partial bulk (has leftover)
- [x] Test: bulkPurchasesNeeded multiple bulks required
- [x] Test: bulkPurchasesNeeded zero bulk quantity guard
- [x] Test: batchPurchaseCost multiplies purchases by bulk cost
- [x] Test: batchProductionCost multiplies per-unit cost by batch size
- [x] Test: batchCostPerUnit equals single-unit production cost
- [x] Test: batchProductionCost batch of 1 equals single-unit production cost
- [x] Test: batchRevenue multiplies gross revenue by batch size
- [x] Test: batchTotalFees includes fixed fee per transaction scaled by batch
- [x] Test: batchProfit multiplies per-sale profit by batch size
- [x] Test: batchProfit negative profit scales correctly
- [x] Test: full batch forecast with known product — all outputs internally consistent
- [x] Test: empty product with no steps or materials — all batch values are zero
- [x] Test: product with costs but no pricing — batch revenue is zero

---

## Build & Development Workflow

**Development machine:** Windows 11. No local Mac. Xcode is not available locally.

### How to develop on Windows
1. Write Swift code in **VS Code** with the `Swift` extension (swiftlang)
2. Swift for Windows provides SourceKit-LSP: syntax highlighting, IntelliSense, and error squiggles in `.swift` files
3. Pure Swift (non-UI) code can be compiled and run locally. SwiftUI and SwiftData require Apple SDKs and cannot run on Windows.
4. Push to GitHub — CI handles the full build and test run on a real macOS machine

### How the Xcode project is managed (XcodeGen)
- The `.xcodeproj` file is **not committed to git** (it is in `.gitignore`)
- Instead, `project.yml` in the repo root defines the full project structure
- To regenerate the project: `xcodegen generate` (requires macOS)
- GitHub Actions runs `xcodegen generate` automatically before every build
- When using MacInCloud for an interactive session: `git pull && xcodegen generate`

### Adding a new Swift file to the project
No Xcode needed. Create the `.swift` file in the correct directory. XcodeGen automatically picks up all `.swift` files on the next `xcodegen generate` run.

### Registering a new SwiftData model
Add it to the `Schema([...])` array in `MakerMarginsApp.swift`. The CI build will catch schema registration errors immediately.

### GitHub Actions CI (`.github/workflows/ci.yml`)
Runs on every push:
1. `brew install xcodegen`
2. `xcodegen generate`
3. `xcodebuild -downloadPlatform iOS` — downloads simulator runtime
4. `xcrun simctl create` + `boot` — creates a concrete "CI iPhone" (iPhone 16) simulator
5. `xcodebuild build` — uses the created simulator by UDID, `CODE_SIGNING_ALLOWED=NO`
6. `xcodebuild test` — runs `MakerMarginsTests` only, same simulator
7. Uploads `.xcresult` artifact

### Interactive Mac sessions (MacInCloud)
- Use for: Simulator output, visual layout debugging, App Store steps
- Cost: ~$1/hour at macincloud.com
- First step every session: `git pull && xcodegen generate`

---

## Architecture Conventions

- **SwiftData** models live in `Models/`, use `@Model final class`, no explicit `id` property.
- **Views** live in `Views/` organised by feature subdirectory.
- **All calculation logic** lives in `Engine/CostingEngine.swift` — never in model computed properties.
- **All currency formatting** routes through `Engine/CurrencyFormatter.swift` — never inline.
- **Appearance management** routes through `Engine/AppearanceManager.swift`. Follows the same `@Observable` + `EnvironmentKey` pattern as `CurrencyFormatter`. Accessed via `@Environment(\.appearanceManager)`. Persists user's System/Light/Dark choice to `UserDefaults`.
- **Labor rate management** routes through `Engine/LaborRateManager.swift`. Same `@Observable` + `EnvironmentKey` + `UserDefaults` pattern. Accessed via `@Environment(\.laborRateManager)`. Provides `defaultRate` for pre-filling new WorkStep labor rates.
- **CostingEngine** is a caseless `enum` (pure namespace) with `static` functions. Model-based overloads accept `WorkStep`/`Product`; raw-value overloads accept primitives for form previews. Labor calculations traverse `Product.productWorkSteps` → `WorkStep`.
- **Tests** use `import Testing` and `@Test` macros (Swift Testing framework). One file per Epic: `EpicNTests.swift`. Do NOT use `XCTestCase`.
- All monetary values use `Decimal` (never `Double`) to avoid floating-point drift.
- `TimeInterval` (seconds as `Double`) is acceptable for time tracking. The `/ 3600` conversion is done in `CostingEngine` only — never at the model layer.
- Buffers and percentages are stored as decimal fractions (0.10 = 10%), never as whole numbers.
- **All styling tokens** (colors, spacing, corner radii, typography, sizing) are defined in `Theme/AppTheme.swift`. Use `AppTheme.*` tokens in views — never hardcode colors or magic numbers.
- **Background layering:** Use `.appBackground()` (from `ViewModifiers.swift`) on all page-level views (ScrollView, List). For `List` views, also apply `.scrollContentBackground(.hidden)` before `.appBackground()`. Color hierarchy: `AppTheme.Colors.surface` (page) < `surfaceElevated` (cards via `.cardStyle()`).

---

## Key Decisions & Notes

- **Sub-tabs in ProductDetailView (Build | Price | Forecast):** Replaces the single-scrollable layout. Pinned header shows compact product context (category badge, description) + segmented picker. Product image moved to Build tab to keep pinned area compact. `.navigationBarTitleDisplayMode(.inline)` used to save vertical space. NavigationDestination modifiers remain on the outer VStack so navigation works across all tabs. Auto-switches to Build tab when a new step/material is created via `pendingWorkStep`/`pendingMaterial`.
- **Solo-maker focus:** The app targets individual makers, not businesses with employees. All labor is framed as the maker's own time. Take-home (profit + labor) is a first-class metric. No employee-specific features.
- **Solo-maker language:** Settings and work step detail views use personal framing ("Your Hourly Rate", "Your Hours / Product", "Your Time Cost") to reinforce that labor = the maker's own time and income. Cost summary and production cost labels keep generic terms ("Labor", "Labor Cost") for consistency in tabular contexts.
- **`summary` not `description`:** The schema's "description" field is `summary` in all Swift models to avoid shadowing `NSObject.description`. This applies to `Product.summary`, `WorkStep.summary`, `Material.summary`.
- **Labor rate on ProductWorkStep (join model), not WorkStep:** Allows the same step to have different rates in different product contexts (e.g. shop rate vs. commissioned rate). Defaults from LaborRateManager. Supports mixed-skill workflows (e.g. machining at $25/hr vs. finishing at $15/hr) while also allowing per-product overrides.
- **`batchUnitsCompleted` defaults to 1:** Prevents division-by-zero in `CostingEngine`. Never allow 0. Validate in forms.
- **`bulkQuantity` defaults to 1:** Same reason.
- **PlatformFeeProfile is a single universal defaults record:** Not per-platform. Stores default values for all editable pricing fields. Per-product overrides live on `ProductPricing`.
- **Shared WorkSteps (many-to-many):** Steps are reusable across products via the `ProductWorkStep` join model. Edit once, updates everywhere. The Workshop tab serves as the step library. Per-product ordering is stored in `ProductWorkStep.sortOrder`.
- **Cascade deletes:** Deleting a Product deletes its `ProductWorkStep` and `ProductMaterial` associations, but shared WorkSteps and Materials survive in their libraries. Deleting a WorkStep cascades to its `ProductWorkStep` associations. Deleting a Material cascades to its `ProductMaterial` associations. Deleting a Category does NOT delete its Products (nullify rule).
- **Shared Materials (many-to-many):** Materials are reusable across products via the `ProductMaterial` join model (mirrors WorkStep/ProductWorkStep exactly). Edit once, updates everywhere. The Materials tab serves as the material library. Per-product ordering is stored in `ProductMaterial.sortOrder`.
- **Per-section buffers:** `laborBuffer` applies only to labor cost, `materialBuffer` applies only to material cost. Shipping is never buffered. Formula: `labor × (1 + laborBuffer) + material × (1 + materialBuffer) + shipping`.
- **Product duplication re-links materials:** Duplicated products get new `ProductMaterial` associations pointing to the same shared Material entities (not deep-copied). Consistent with WorkStep duplication behavior.
- **Image storage:** `Data?` blob in SwiftData for Epic 0–6. Migrate to file-system URLs in Epic 7 if performance requires it.
- **Currency:** USD default, EUR option. Stored `Decimal` values are always in the user's chosen currency. No conversion logic — user picks one currency and sticks with it.
- **Appearance management pattern:** `AppearanceManager` follows the same `@Observable` + `EnvironmentKey` + `UserDefaults` pattern as `CurrencyFormatter`. New app-level managers should follow this pattern. Injected at root in `MakerMarginsApp.swift`, accessed via `@Environment`.
- **Background layering:** Two-tier warm background system — `surface` (page-level, subtle warm cream) and `surfaceElevated` (card-level, near-white in light / warm charcoal in dark). All colors use `UIColor { traits in ... }` closures for automatic dark/light adaptation.
- **Color system:** Amber accent for costs/interactive elements, sage green for category badges and tab bar tint. Cards use adaptive border stroke (`cardBorder`) + subtle shadow.
- **Reusable thumbnail components:** `ProductThumbnailView` (Epic 1, private to ProductListView) and `WorkStepThumbnailView` (Epic 2) in `ViewModifiers.swift`. Use these instead of duplicating image/placeholder logic in list rows.
- **Labor list uses VStack, not List:** `WorkStepListView` renders steps in a plain `VStack` + `ForEach` (not `List`) to avoid nested-scrollable-container issues. NavigationLinks work normally; reorder uses a toggle button with up/down arrows; remove uses context menu.
- **Form input behavior:** All numeric fields in `WorkStepFormView` use `@FocusState` to clear default values on focus and restore them on blur. Time fields (minutes/seconds) are clamped to 0–59 with digit-only validation.
- **Dynamic unit labels:** Form and detail views use the step's `unitName` dynamically in labels (e.g. "Units per Batch", "Boards per Product", "Time per board").
- **Batch-oriented labels:** WorkStep forms and detail views use "Time to Complete Batch" and "Units per Batch" (not "Recorded Time" / "Units Completed") to clearly convey batch-level semantics.
- **Conditional delete vs. remove in detail views:** `WorkStepDetailView` and `MaterialDetailView` hide the "Delete" toolbar action when opened from a product context (`product != nil`). Instead, a "Remove from [Product]" button is shown at the bottom, which unlinks the item from the product without deleting it. Global deletion is only available from the library tabs (Labor / Materials).
- **Auto-navigation after item creation:** When a new WorkStep or Material is created from within `ProductDetailView`, the app auto-navigates to the new item's detail view via `onNewStepCreated`/`onNewMaterialCreated` callbacks and `navigationDestination(item:)`. This lets users immediately adjust product-specific settings (labor rate, units per product).
- **`.editableFieldStyle()` modifier:** Applies a subtle rounded `inputBackground` fill (tertiarySystemFill) around individual editable fields to visually distinguish them from read-only values. Applied to: labor rate, units per product, buffer percentages, and shipping cost fields. Defined in `ViewModifiers.swift`.
- **CurrencyInputField:** Reusable component in `ViewModifiers.swift` that groups currency symbol + TextField + optional suffix into a cohesive input unit. Used for labor rate and bulk cost fields.
- **CostingEngine.formatHours():** Formats `Decimal` hours to 4 decimal places with trailing zero stripping (minimum 2 decimals). Used for Hours/Unit and Labor Hrs/Product displays. Centralised alongside `formatDuration()`.
- **Category management is inline-only:** Categories are created from within `ProductFormView`'s category picker. The Settings → Categories navigation link has been removed. `CategoryListView` and `CategoryFormView` are legacy files.
- **Platform pricing uses fixed tabs, not named profiles:** The original spec had user-created named profiles ("My Etsy Shop"). Epic 4 uses fixed platform tabs (General, Etsy, Shopify, Amazon) with locked fees. Simpler UX, no profile management.
- **Split fee model (platformFee + paymentProcessingFee + paymentProcessingFixed):** Fees are split into platform commission, payment processing (% + optional fixed $), and marketing. Locked fees display as formatted strings (e.g. "3% + $0.25"). General tab is percent-only (no fixed fees).
- **Locked/editable rules per platform:** General: all editable. Etsy: platform fee, processing, and marketing all locked. Shopify/Amazon: platform fee and processing locked, marketing editable. % Sales from Ads and Profit Margin always editable.
- **Marketing fee frequency model:** `effectiveMarketing = marketingFee × percentSalesFromMarketing`. Handles Etsy offsite ads (15% on ~20% of sales = 3% effective). Generalises to Shopify/Amazon where users enter their own ad cost rate and conversion frequency.
- **Single universal pricing defaults:** Settings has one form (not split by platform) with defaults for all 5 editable fields. These pre-fill editable fields across all platform tabs — locked fees are never overridden by defaults.
- **Locked vs editable platform fees:** Platform-imposed fees are hardcoded constants on `PlatformType` (not persisted). Only user-configurable values are stored in `PlatformFeeProfile` (defaults) and `ProductPricing` (per-product overrides).
- **Lazy creation for pricing records:** Both `PlatformFeeProfile` and `ProductPricing` are created on first access, not eagerly. Avoids creating records for platforms the user never uses.
- **Pricing section background:** `AppTheme.Colors.pricingSurface` provides a subtle warm tint to visually distinguish the pricing calculator from the product-building sections above.
- **PercentageInputField + PercentageFormat:** Shared components in `ViewModifiers.swift`. Users type whole numbers (30 for 30%), models store fractions (0.30). Conversion centralised in `PercentageFormat.toDisplay()`/`fromDisplay()`.
- **Template data is pure Swift structs:** `ProductTemplates.swift` imports only `Foundation` — no SwiftData. Template structs mirror model init signatures so `TemplateApplier` maps fields directly. Keeps template definitions testable and decoupled.
- **TemplateApplier is a caseless enum:** Matches `CostingEngine` pattern. Single `static func apply(_:to:) throws -> Product`. No `context.save()` inside — SwiftData auto-saves, tests control save timing.
- **Title-based deduplication:** Shared WorkSteps and Materials are matched by exact title string. Fetch-all + in-memory filter pattern (consistent with zero `#Predicate` usage in the codebase). Entity-level fields must be identical across templates sharing a title; per-product fields (laborRate, unitsRequiredPerProduct) live on join models.
- **Template images bundled in Asset Catalog:** `Assets.xcassets` contains 42 image sets (5 products + 18 steps + 19 materials). Loaded via `UIImage(named:)?.jpegData(compressionQuality: 0.8)`. Empty `imageName` returns nil gracefully. Images ship in the app binary.
- **ProductListView toolbar "+" is a Menu:** Contains "Blank Product" and "From Template" options. Both use the same `newlyCreatedProduct` + `onDismiss` navigation pattern.
- **Template names are workflow-focused:** Titles like "Woodworking Template" (not "Hardwood Cutting Board") to communicate that templates are starting points for any product in that category. Each has a TMPL-prefixed SKU.
- **Fees on price + shipping in profit analysis:** Platform and processing percentage fees apply to `actualPrice + actualShippingCharge` (the full customer payment), matching real Etsy/Shopify/Amazon behavior. Marketing fees apply to `actualPrice` only (Etsy offsite ads don't apply to shipping).
- **Separate GroupBox for profit analysis:** "Target Price Calculator" answers "what should I charge?" and "Profit Analysis" answers "what am I actually making?" Separate GroupBoxes maintain clear mental models while sharing the same platform tabs via `selectedPlatform` state.
- **"Your Earnings" as single hero metric:** Solo makers' labor cost is their income. The hero card shows one clear answer — "Your Earnings / Sale" (= actualProfit + laborCostBuffered) — instead of two competing profit numbers. "Margin After Costs" (the old "Profit per Sale") and "+ Your Labor" appear as secondary breakdown lines below the hero, preserving educational value without visual competition. "Effective Hourly Rate" (the old "Take-Home / Hr") answers "is this product worth my time?" Batch Forecast uses the same pattern: "Batch Earnings" hero + "Earnings / Unit" + "Margin After Costs" breakdown. All breakdown rows hidden when no labor exists (earnings = margin, so showing both would be redundant).
- **Template actual prices below target:** All 5 templates set `actualPrice` below the computed target price, demonstrating the common real-world scenario that motivates the "What am I actually making?" question. Shipping strategies vary (absorb, pass-through, mark up).
- **No actual price defaults in PlatformFeeProfile:** Actual pricing is inherently per-product — a $15 candle and $85 cutting board from the same shop have different prices. Only fee-related defaults are stored globally.
- **Batch forecasting is session state only:** Batch size is `@State` — not persisted to SwiftData. This is a calculator, not a production plan. Resets when navigating away. Default of 10 gives meaningful numbers on first view.
- **Single input drives everything:** The batch size number is the only user input in the Forecast tab. All sections (labor time, shopping list, costs, revenue) derive from `product` data × `batchSize`. No configuration, no settings.
- **Material shopping list with purchase recommendations:** `bulkPurchasesNeeded` uses ceiling division to tell makers exactly how many packages to buy. Shows leftover units. "Total Purchase Cost" (what you spend at the store) is distinct from "Material Cost" (what goes into production cost) — the difference is surplus from bulk packaging.
- **Revenue forecast is conditional:** Only shown when at least one `ProductPricing` has `actualPrice > 0`. Uses the first matching pricing record. When no pricing exists, a hint directs users to the Price tab.
- **Batch functions delegate to existing per-unit functions:** All `batchX` functions in CostingEngine are `existingPerUnitFunction × batchSize`. This ensures batch calculations are always consistent with single-unit calculations and avoids duplicating math.
- **`formatHoursReadable` drops seconds:** Batch-level time display uses "Xh Ym" format (not "Xh Ym Zs") because second-level precision is meaningless for multi-unit production forecasts. Converts Decimal hours to Double before multiplying by 3600 to avoid `NSDecimalNumber.intValue` truncation on chained Decimal arithmetic.
- **`activePricing` prefers platform-specific over General:** Revenue forecast selects the pricing with the highest `actualPrice` among platform-specific records (Etsy/Shopify/Amazon), falling back to General only if no platform-specific pricing exists. This prevents lazily-created General records from shadowing template Etsy pricing.
- **Per-unit labor time uses minutes:** The per-unit context line in labor forecast rows shows "23m/ea" or "1h 15m/ea" instead of "0.375 hrs/ea" — more intuitive for makers. Batch totals keep decimal precision.
- **Zero-value rows hidden in revenue breakdown:** Fee, production cost, and shipping rows in the revenue forecast section are hidden when their value is zero, avoiding "-$0.00" display artifacts.
- **No CloudKit, no authentication, no sync.** Single-user, local-only.
