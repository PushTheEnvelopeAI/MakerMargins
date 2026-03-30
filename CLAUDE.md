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
| 4 | Pricing Calculator & Platform Tabs + E2E Tests | Pending |
| 5 | Batch Forecasting Widgets + E2E Tests | Pending |
| 6 | Production Readiness & App Store Launch | Pending |

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
| laborRate | Decimal | $/hour. Defaults to LaborRateManager.defaultRate for new steps |
| recordedTime | TimeInterval | Seconds — total time for the batch run. Set manually or via StopwatchView |
| batchUnitsCompleted | Decimal | Units produced in that batch. **Default: 1** (guards against division by zero) |
| unitName | String | e.g. "piece", "board". **Default: "unit"** |
| unitsRequiredPerProduct | Decimal | Steps per finished product. **Default: 1** |
| productWorkSteps | [ProductWorkStep] | One-to-many to join model, cascade delete (deleting a step removes all its associations) |

### ProductWorkStep
Join model enabling many-to-many between Product and WorkStep with per-product ordering.

| Swift Property | Type | Notes |
|----------------|------|-------|
| product | Product? | Many-to-one |
| workStep | WorkStep? | Many-to-one |
| sortOrder | Int | Per-product display order. **Default: 0** |

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
| Swift Property | Type | Notes |
|----------------|------|-------|
| name | String | User-facing label e.g. "My Etsy Shop" |
| platformType | PlatformType | Enum: `.general` `.etsy` `.shopify` `.amazon` |
| feePercentage | Decimal | Platform fee as a fraction e.g. 0.065 = 6.5% |
| marginGoal | Decimal | Target profit margin as a fraction. **Default: 0.30** |

> `PlatformType` is a `String`-backed `Codable` enum defined in `PlatformFeeProfile.swift`. Fee structure defaults per platform to be defined in Epic 4.

---

## Calculation Logic (The Math)

All calculations are implemented in `Engine/CostingEngine.swift` — **not** as computed properties on the models. Models are pure data; CostingEngine is pure logic. `CostingEngine` is a caseless `enum` (pure namespace) with `static` functions. Labor calculations implemented (Epic 2); material calculations implemented (Epic 3).

Each function has a model-based overload (accepts `WorkStep`/`Product`) and a raw-value overload (accepts `TimeInterval`/`Decimal` primitives) for real-time form previews before a model is saved.

```
// WorkStep level
unitTime      = recordedTime / batchUnitsCompleted      // seconds per unit
unitTimeHours = unitTime / 3600                          // convert to hours

// Product Labor (per WorkStep)
// laborRate is $/hour — MUST use unitTimeHours, never raw seconds
stepLaborCost = (unitTimeHours * unitsRequiredPerProduct) * laborRate

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

// Target Retail Price (given a PlatformFeeProfile)
targetRetailPrice = totalProductionCost / (1 - (feePercentage + marginGoal))
```

**Division-by-zero guards:** `batchUnitsCompleted` and `bulkQuantity` both default to 1. CostingEngine must still guard against zero before dividing.

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
│   ├── MakerMarginsApp.swift              ← @main entry point, ModelContainer with all 7 models
│   ├── ContentView.swift                  ← 4-tab TabView shell (Products, Labor, Materials, Settings)
│   │
│   ├── Models/                            ← SwiftData @Model types (all implemented)
│   │   ├── Product.swift
│   │   ├── Category.swift
│   │   ├── WorkStep.swift                 ← shared entity (many-to-many via ProductWorkStep)
│   │   ├── ProductWorkStep.swift          ← join model: Product ↔ WorkStep with sortOrder
│   │   ├── Material.swift                 ← shared entity (many-to-many via ProductMaterial)
│   │   ├── ProductMaterial.swift          ← join model: Product ↔ Material with sortOrder
│   │   └── PlatformFeeProfile.swift       ← also contains PlatformType enum
│   │
│   ├── Engine/                            ← calculation, formatting & app-level managers
│   │   ├── CostingEngine.swift            ← labor + material calculations implemented (Epic 2-3)
│   │   ├── CurrencyFormatter.swift        ← implemented Epic 1
│   │   ├── AppearanceManager.swift        ← System/Light/Dark toggle, UserDefaults-persisted
│   │   └── LaborRateManager.swift         ← default hourly rate, UserDefaults-persisted (Epic 2)
│   │
│   ├── Theme/                             ← design system tokens and reusable view modifiers
│   │   ├── AppTheme.swift                 ← colors (surface, surfaceElevated, accent, categoryBadge, tabTint, cardBorder, etc.), spacing, corner radii, typography, sizing
│   │   └── ViewModifiers.swift            ← .cardStyle(), .appBackground(), PlaceholderImageView, WorkStepThumbnailView, MaterialThumbnailView
│   │
│   └── Views/                             ← SwiftUI views, grouped by feature
│       ├── Products/                      ← Tab 1 root + all product-owned views
│       │   ├── ProductListView.swift      ← Tab 1 root (NavigationStack), product duplication via context menu — Epic 1
│       │   ├── ProductDetailView.swift    ← scrollable hub: header, cost summary, labor, materials — Epic 1+2
│       │   ├── ProductFormView.swift      ← create/edit sheet, inline category creation — Epic 1
│       │   ├── ProductCostSummaryCard.swift ← cost breakdown card (labor + materials live) — Epic 2+3
│       │   ├── PricingCalculatorView.swift  ← inline section in ProductDetailView — STUB
│       │   └── BatchForecastView.swift      ← inline section in ProductDetailView — STUB
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
│           ├── SettingsView.swift         ← Tab 4 root: currency, appearance, labor rate, nav rows — Epic 1+2
│           ├── PlatformFeeProfileListView.swift ← pushed from SettingsView — STUB
│           └── PlatformFeeProfileFormView.swift ← create/edit sheet — STUB
│
├── MakerMarginsTests/                     ← Swift Testing suite (import Testing, @Test)
│   ├── Epic0Tests.swift                   ← Complete: test harness smoke test
│   ├── Epic1Tests.swift                   ← Complete: Product/Category CRUD, cascade, CurrencyFormatter, product duplication (13 tests)
│   ├── Epic2Tests.swift                   ← Complete: WorkStep/join CRUD, CostingEngine, reorder, LaborRateManager (12 tests)
│   ├── Epic3Tests.swift                   ← Complete: Material/join CRUD, CostingEngine material calcs, per-section buffers, duplication (12 tests)
│   ├── Epic4Tests.swift                   ← STUB
│   └── Epic5Tests.swift                   ← STUB
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
└── [push] ProductDetailView               [Level 1 — scrollable hub]
    │   Cost Summary (ProductCostSummaryCard)
    │   Labor Workflow section (inline WorkStepListView — VStack, not List)
    │   Materials section (inline MaterialListView content)
    │   Pricing section (inline PricingCalculatorView content)
    │   Forecast section (inline BatchForecastView content)
    ├── [push] WorkStepDetailView          [Level 2 — edit/stopwatch buttons in toolbar]
    │   └── [fullScreenCover] StopwatchView  [Level 3 — MAX DEPTH, pause/resume]
    ├── [push] MaterialDetailView          [Level 2 — edit/delete buttons in toolbar]
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
SettingsView                              [ROOT — currency, appearance, labor rate]
└── [push] PlatformFeeProfileListView     [Level 1]
    └── [sheet] PlatformFeeProfileFormView  [create / edit]
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

- **`summary` not `description`:** The schema's "description" field is `summary` in all Swift models to avoid shadowing `NSObject.description`. This applies to `Product.summary`, `WorkStep.summary`, `Material.summary`.
- **Labor rate on WorkStep, not Product:** Supports mixed-skill workflows (e.g. machining at $25/hr vs. finishing at $15/hr).
- **`batchUnitsCompleted` defaults to 1:** Prevents division-by-zero in `CostingEngine`. Never allow 0. Validate in forms.
- **`bulkQuantity` defaults to 1:** Same reason.
- **PlatformFeeProfiles are global:** Not per-product. One profile can be reused across all products.
- **Shared WorkSteps (many-to-many):** Steps are reusable across products via the `ProductWorkStep` join model. Edit once, updates everywhere. The Workshop tab serves as the step library. Per-product ordering is stored in `ProductWorkStep.sortOrder`.
- **Cascade deletes:** Deleting a Product deletes its `ProductWorkStep` and `ProductMaterial` associations, but shared WorkSteps and Materials survive in their libraries. Deleting a WorkStep cascades to its `ProductWorkStep` associations. Deleting a Material cascades to its `ProductMaterial` associations. Deleting a Category does NOT delete its Products (nullify rule).
- **Shared Materials (many-to-many):** Materials are reusable across products via the `ProductMaterial` join model (mirrors WorkStep/ProductWorkStep exactly). Edit once, updates everywhere. The Materials tab serves as the material library. Per-product ordering is stored in `ProductMaterial.sortOrder`.
- **Per-section buffers:** `laborBuffer` applies only to labor cost, `materialBuffer` applies only to material cost. Shipping is never buffered. Formula: `labor × (1 + laborBuffer) + material × (1 + materialBuffer) + shipping`.
- **Product duplication re-links materials:** Duplicated products get new `ProductMaterial` associations pointing to the same shared Material entities (not deep-copied). Consistent with WorkStep duplication behavior.
- **Image storage:** `Data?` blob in SwiftData for Epic 0–5. Migrate to file-system URLs in Epic 6 if performance requires it.
- **Currency:** USD default, EUR option. Stored `Decimal` values are always in the user's chosen currency. No conversion logic — user picks one currency and sticks with it.
- **Appearance management pattern:** `AppearanceManager` follows the same `@Observable` + `EnvironmentKey` + `UserDefaults` pattern as `CurrencyFormatter`. New app-level managers should follow this pattern. Injected at root in `MakerMarginsApp.swift`, accessed via `@Environment`.
- **Background layering:** Two-tier warm background system — `surface` (page-level, subtle warm cream) and `surfaceElevated` (card-level, near-white in light / warm charcoal in dark). All colors use `UIColor { traits in ... }` closures for automatic dark/light adaptation.
- **Color system:** Amber accent for costs/interactive elements, sage green for category badges and tab bar tint. Cards use adaptive border stroke (`cardBorder`) + subtle shadow.
- **Reusable thumbnail components:** `ProductThumbnailView` (Epic 1, private to ProductListView) and `WorkStepThumbnailView` (Epic 2) in `ViewModifiers.swift`. Use these instead of duplicating image/placeholder logic in list rows.
- **Labor list uses VStack, not List:** `WorkStepListView` renders steps in a plain `VStack` + `ForEach` (not `List`) to avoid nested-scrollable-container issues. NavigationLinks work normally; reorder uses a toggle button with up/down arrows; remove uses context menu.
- **Form input behavior:** All numeric fields in `WorkStepFormView` use `@FocusState` to clear default values on focus and restore them on blur. Time fields (minutes/seconds) are clamped to 0–59 with digit-only validation.
- **Dynamic unit labels:** Form and detail views use the step's `unitName` dynamically in labels (e.g. "Boards Completed", "Boards per Product", "Time per board").
- **Category management is inline-only:** Categories are created from within `ProductFormView`'s category picker. The Settings → Categories navigation link has been removed. `CategoryListView` and `CategoryFormView` are legacy files.
- **No CloudKit, no authentication, no sync.** Single-user, local-only.
