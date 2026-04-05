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
| 6 | Portfolio Metrics & Product Comparison + E2E Tests | **Complete** |
| 7 | Production Readiness & App Store Launch | **In Progress** |

Detailed acceptance criteria for Epics 1–6 are archived in `plans/epic-acceptance-criteria.md`.

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
| productWorkSteps | [ProductWorkStep] | Cascade delete (removes associations, NOT the shared WorkSteps) |
| productMaterials | [ProductMaterial] | Cascade delete (removes associations, NOT the shared Materials) |
| productPricings | [ProductPricing] | Cascade delete. Up to 4 (one per PlatformType), created lazily. |

### Category
| Swift Property | Type | Notes |
|----------------|------|-------|
| name | String | |
| products | [Product] | Delete rule: nullify (products are NOT deleted) |

### WorkStep (shared entity)
| Swift Property | Type | Notes |
|----------------|------|-------|
| title | String | |
| summary | String | |
| image | Data? | |
| recordedTime | TimeInterval | Seconds — set manually or via StopwatchView |
| batchUnitsCompleted | Decimal | **Default: 1** (guards against division by zero) |
| unitName | String | e.g. "piece", "board". **Default: "unit"** |
| defaultUnitsPerProduct | Decimal | **Default: 1** |
| productWorkSteps | [ProductWorkStep] | Cascade delete |

### ProductWorkStep (join model)
| Swift Property | Type | Notes |
|----------------|------|-------|
| product | Product? | Many-to-one |
| workStep | WorkStep? | Many-to-one |
| sortOrder | Int | **Default: 0** |
| unitsRequiredPerProduct | Decimal | **Default: 1** |
| laborRate | Decimal | $/hour, per-product. Pre-filled from LaborRateManager. **Default: 0** |

### Material (shared entity)
| Swift Property | Type | Notes |
|----------------|------|-------|
| title | String | |
| summary | String | |
| image | Data? | |
| link | String | Supplier URL. **Default: ""** |
| bulkCost | Decimal | Total cost of bulk purchase |
| bulkQuantity | Decimal | Units in bulk purchase. **Default: 1** |
| unitName | String | **Default: "unit"** |
| unitsRequiredPerProduct | Decimal | **Default: 1** |
| productMaterials | [ProductMaterial] | Cascade delete |

### ProductMaterial (join model)
| Swift Property | Type | Notes |
|----------------|------|-------|
| product | Product? | Many-to-one |
| material | Material? | Many-to-one |
| sortOrder | Int | **Default: 0** |
| unitsRequiredPerProduct | Decimal | **Default: 1** |

### PlatformFeeProfile
Single universal record storing user-configurable default pricing values. Created lazily on first access.

| Swift Property | Type | Notes |
|----------------|------|-------|
| platformFee | Decimal | **Default: 0** |
| paymentProcessingFee | Decimal | **Default: 0** |
| marketingFee | Decimal | **Default: 0** |
| percentSalesFromMarketing | Decimal | **Default: 0** |
| profitMargin | Decimal | **Default: 0.30** |

> `PlatformType` is a `String`-backed `Codable` enum defined in `PlatformFeeProfile.swift`. Has locked fee constants, editability flags, and display name/icon helpers. Display formatting methods (`platformFeeDisplay()`, `paymentProcessingDisplay()`, `marketingFeeDisplay()`) live in `Engine/PlatformFeeFormatter.swift` as extension methods on `PlatformType`.

### ProductPricing
Per-product per-platform pricing overrides. Up to 4 per product (one per `PlatformType`). Created lazily.

| Swift Property | Type | Notes |
|----------------|------|-------|
| product | Product? | Many-to-one |
| platformType | PlatformType | |
| platformFee | Decimal | **Default: 0** |
| paymentProcessingFee | Decimal | **Default: 0** |
| marketingFee | Decimal | **Default: 0** |
| percentSalesFromMarketing | Decimal | **Default: 0** |
| profitMargin | Decimal | **Default: 0.30** |
| actualPrice | Decimal | **Default: 0** |
| actualShippingCharge | Decimal | **Default: 0** |

---

## Calculation Logic (The Math)

All calculations live in `Engine/CostingEngine.swift` — a caseless `enum` with `static` functions. Models are pure data; CostingEngine is pure logic. Each function has a model-based overload and a raw-value overload for form previews.

```
// Per-step
unitTimeHours = recordedTime / batchUnitsCompleted / 3600
laborHoursPerProduct = unitTimeHours * unitsRequiredPerProduct
stepLaborCost = laborHoursPerProduct * laborRate

// Per-product
totalLaborCost = sum of stepLaborCost across all ProductWorkSteps
totalMaterialCost = sum of (bulkCost / bulkQuantity * unitsRequired) across all ProductMaterials
totalProductionCost = totalLaborCost * (1 + laborBuffer) + totalMaterialCost * (1 + materialBuffer) + shippingCost

// Target pricing
effectiveMarketing = marketingFee * percentSalesFromMarketing
targetRetailPrice = (totalProductionCost + paymentProcessingFixed) / (1 - (totalPercentFees + profitMargin))
// Returns nil if denominator <= 0

// Profit analysis
grossRevenue = actualPrice + actualShippingCharge
totalSaleFees = grossRevenue * (platformFee + processingFee) + actualPrice * effectiveMarketing + processingFixed
actualProfit = grossRevenue - totalSaleFees - productionCostExShipping - shippingCost
earningsPerSale = actualProfit + totalLaborCostBuffered   // "Your Earnings / Sale"
hourlyPay = earningsPerSale / totalLaborHours             // "Your Hourly Pay"

// Batch forecasting
batchX = perUnitX * batchSize  (all batch functions delegate to per-unit functions)
bulkPurchasesNeeded = ceil(batchMaterialUnits / bulkQuantity)

// Portfolio
productSnapshot = single-pass computation of all metrics per product per platform
portfolioAverages = averages across priced products only
```

**Division-by-zero guards:** `batchUnitsCompleted` and `bulkQuantity` default to 1. All CostingEngine division operations guard against zero and return nil or 0.

---

## Directory Layout

```
MakerMargins/                              <- repo root
+-- CLAUDE.md                              <- this file
+-- project.yml                            <- XcodeGen spec (generates .xcodeproj)
+-- .gitignore                             <- excludes .xcodeproj, DerivedData, build/
+-- .github/workflows/ci.yml              <- GitHub Actions: XcodeGen -> build -> test
|
+-- MakerMargins/                          <- main app target
|   +-- MakerMarginsApp.swift              <- @main entry point, ModelContainer (8 models), in-memory fallback on corruption
|   +-- ContentView.swift                  <- 4-tab TabView shell (Products, Labor, Materials, Settings)
|   |
|   +-- Models/
|   |   +-- Product.swift
|   |   +-- Category.swift
|   |   +-- WorkStep.swift                 <- shared entity (many-to-many via ProductWorkStep)
|   |   +-- ProductWorkStep.swift          <- join model with sortOrder + laborRate
|   |   +-- Material.swift                 <- shared entity (many-to-many via ProductMaterial)
|   |   +-- ProductMaterial.swift          <- join model with sortOrder
|   |   +-- PlatformFeeProfile.swift       <- universal pricing defaults + PlatformType enum
|   |   +-- ProductPricing.swift           <- per-product per-platform pricing overrides
|   |
|   +-- Engine/
|   |   +-- CostingEngine.swift            <- all calculation logic (labor, material, pricing, batch, portfolio)
|   |   +-- CurrencyFormatter.swift        <- USD/EUR formatting
|   |   +-- AppearanceManager.swift        <- System/Light/Dark toggle
|   |   +-- LaborRateManager.swift         <- default hourly rate
|   |   +-- PlatformFeeFormatter.swift     <- display formatting for locked platform fees
|   |   +-- ProductTemplates.swift         <- pure-data template definitions (5 workflows)
|   |   +-- TemplateApplier.swift          <- hydrates templates into SwiftData entities with dedup
|   |
|   +-- Theme/
|   |   +-- AppTheme.swift                 <- colors, spacing, corner radii, typography, sizing, shadow
|   |   +-- ViewModifiers.swift            <- shared components and view modifiers (see Shared Components below)
|   |
|   +-- Assets.xcassets/                   <- AppIcon + 42 template image sets
|   |
|   +-- Views/
|       +-- Products/
|       |   +-- ProductListView.swift      <- Tab 1 root, list/grid, duplication, template picker, portfolio link
|       |   +-- ProductDetailView.swift    <- pinned header + sub-tabs (Build/Price/Forecast), duplication
|       |   +-- ProductFormView.swift      <- create/edit sheet, inline category creation
|       |   +-- ProductCostSummaryCard.swift <- cost breakdown (labor + materials + shipping)
|       |   +-- PricingCalculatorView.swift <- collapsible target price + profit analysis, platform tabs
|       |   +-- TemplatePickerView.swift   <- 2-column template grid with content preview
|       |   +-- BatchForecastView.swift    <- batch forecasting (labor, shopping list, revenue)
|       |   +-- PortfolioView.swift        <- portfolio comparison (rankings, cost breakdown)
|       +-- Workshop/
|       |   +-- WorkshopView.swift         <- Tab 2 "Labor", searchable step library, auto-navigate on create
|       +-- Labor/
|       |   +-- WorkStepListView.swift     <- inline step list in ProductDetailView
|       |   +-- WorkStepDetailView.swift   <- detail with stopwatch shortcut in toolbar
|       |   +-- WorkStepFormView.swift     <- create/edit sheet
|       |   +-- StopwatchView.swift        <- fullScreenCover, always-visible dismiss
|       +-- Materials/
|       |   +-- MaterialsLibraryView.swift <- Tab 3, searchable material library, auto-navigate on create
|       |   +-- MaterialListView.swift     <- inline material list in ProductDetailView
|       |   +-- MaterialDetailView.swift   <- detail with tappable "Used By" products
|       |   +-- MaterialFormView.swift     <- create/edit sheet
|       +-- Settings/
|           +-- SettingsView.swift         <- Tab 4: currency, appearance, labor rate, pricing defaults
|           +-- PlatformPricingDefaultFormView.swift <- universal pricing defaults form
|
+-- MakerMarginsTests/
|   +-- Epic0Tests.swift through Epic6Tests.swift  <- 152 tests across 9 epic files
|   +-- RefactorTests.swift                         <- 40 tests for formatters, managers, cross-platform, negative inputs
|
+-- MakerMarginsUITests/
    +-- MakerMarginsUITests.swift          <- STUB
```

---

## Navigation Structure

**4-Tab TabView.** ContentView owns only the TabView — no state, no queries. Each tab root owns its own `NavigationStack`.

| Tab | Root View | SF Symbol |
|-----|-----------|-----------|
| 1 | `ProductListView` | `square.grid.2x2` |
| 2 | `WorkshopView` | `hammer` |
| 3 | `MaterialsLibraryView` | `shippingbox` |
| 4 | `SettingsView` | `gearshape` |

### Tab 1 — Products
```
ProductListView                            [ROOT — context menu: Duplicate (auto-navigates), Delete]
+-- [push] PortfolioView                   [platform picker, sort, rankings, cost breakdown]
|   +-- [push] ProductDetailView
+-- [push] ProductDetailView               [pinned header + sub-tabs: Build | Price | Forecast]
    |   Build: image, cost summary, labor workflow, materials, shipping
    |   Price: collapsible target calculator + profit analysis (platform tabs)
    |   Forecast: batch size -> labor/materials/revenue
    +-- [push] WorkStepDetailView          [stopwatch shortcut in toolbar; edit; "Remove from Product"]
    |   +-- [fullScreenCover] StopwatchView
    +-- [push] MaterialDetailView          [edit; "Remove from Product"]
    +-- [sheet] ProductFormView / WorkStepFormView / MaterialFormView
```

### Tab 2 — Labor (stopwatch in 2 taps)
```
WorkshopView                              [ROOT — searchable step library, auto-navigate on create]
+-- [push] WorkStepDetailView             [stopwatch + edit in toolbar; tappable "Used By" products]
    +-- [fullScreenCover] StopwatchView
    +-- [push] ProductDetailView           [from tappable "Used By" link]
```

### Tab 3 — Materials
```
MaterialsLibraryView                      [ROOT — searchable material library, auto-navigate on create]
+-- [push] MaterialDetailView             [edit in toolbar; tappable "Used By" products]
    +-- [push] ProductDetailView           [from tappable "Used By" link]
```

### Tab 4 — Settings
```
SettingsView                              [ROOT — currency, appearance, labor rate, pricing defaults]
+-- [push] PlatformPricingDefaultFormView
```

---

## Shared Components (ViewModifiers.swift)

Reusable UI components extracted from the WorkStep/Material parallel hierarchies:

| Component | Purpose |
|-----------|---------|
| `ItemRow<Thumbnail>` | List row: thumbnail + title + cost + detail + chevron |
| `ReorderRow<Thumbnail>` | Reorder mode: thumbnail + title + up/down arrows (44pt targets) |
| `BufferInputSection` | Buffer % input with label, helper text, focus behavior, and buffered total |
| `ItemHeaderView` | Detail view: image/placeholder + summary |
| `UsedBySection` | "Used By" GroupBox with tappable NavigationLinks (library) or plain rows (product) |
| `RemoveFromProductButton` | Destructive "Remove from [Product]" button |
| `CurrencyInputField` | Currency symbol + TextField + optional suffix |
| `PercentageInputField` | Percentage field with whole-number display, fraction storage |
| `CalculatorSectionHeader` | Icon + small-caps title for calculator sections |
| `DetailRow` / `DerivedRow` | Label + value rows (DerivedRow uses accent color for computed values) |
| Thumbnail views | `WorkStepThumbnailView`, `MaterialThumbnailView`, `ProductThumbnailView` |
| View modifiers | `.cardStyle()`, `.heroCardStyle()`, `.sectionGroupStyle()`, `.editableFieldStyle()`, `.appBackground()` |

---

## Architecture Conventions

- **Models** live in `Models/`, use `@Model final class`, no explicit `id` property.
- **All calculation logic** lives in `Engine/CostingEngine.swift` — never in view bodies or model computed properties. CostingEngine imports only `Foundation`.
- **All currency formatting** routes through `Engine/CurrencyFormatter.swift`.
- **Display formatting** for platform fees lives in `Engine/PlatformFeeFormatter.swift` (extension on `PlatformType`).
- **Managers** (CurrencyFormatter, AppearanceManager, LaborRateManager) follow `@Observable` + `EnvironmentKey` + `UserDefaults` pattern. Injected at root, accessed via `@Environment`.
- **All styling tokens** defined in `Theme/AppTheme.swift` — colors, spacing, corner radii, typography, sizing, shadow. Never hardcode values in views.
- **Accessibility:** All custom buttons have `.accessibilityLabel`. Hero values include context. Decorative images use `.accessibilityHidden(true)`. Composite cards use `.accessibilityElement(children: .combine)`. Touch targets >= 44pt. `reduceMotion` guards animations.
- **Form safety:** All form sheets use `.interactiveDismissDisabled(hasUnsavedChanges)`. All views with `@FocusState` have a keyboard "Done" toolbar. Title validation trims whitespace and shows inline hint.
- **Tests** use `import Testing` and `@Test` macros. One file per epic plus `RefactorTests.swift`. 192 tests total. Do NOT use XCTest.
- All monetary values use `Decimal` (never `Double`). Buffers/percentages stored as fractions (0.10 = 10%).

---

## Build & Development Workflow

**Development machine:** Windows 11. No local Mac. Xcode is not available locally.

### How to develop on Windows
1. Write Swift code in **VS Code** with the `Swift` extension (swiftlang)
2. Pure Swift (non-UI) code can be compiled and run locally. SwiftUI and SwiftData require Apple SDKs.
3. Push to GitHub — CI handles the full build and test run on a real macOS machine

### XcodeGen
- `.xcodeproj` is in `.gitignore` — generated from `project.yml`
- `xcodegen generate` runs automatically in CI
- New `.swift` files are auto-discovered by XcodeGen
- New SwiftData models must be added to the `Schema([...])` in `MakerMarginsApp.swift`

### GitHub Actions CI
Runs on every push: XcodeGen -> download iOS platform -> create iPhone 16 simulator -> build (`CODE_SIGNING_ALLOWED=NO`) -> test -> upload `.xcresult`

---

## Key Decisions

- **Solo-maker focus:** The app targets individual makers, not businesses with employees. All labor is framed as the maker's own time. "Your Earnings" (profit + labor) is the hero metric, not raw profit.
- **`summary` not `description`:** All models use `summary` to avoid shadowing `NSObject.description`.
- **Labor rate on join model:** `ProductWorkStep.laborRate` (not `WorkStep`) allows different rates per product context (e.g. shop rate vs. commissioned rate).
- **Division-by-zero defaults:** `batchUnitsCompleted` and `bulkQuantity` default to 1. CostingEngine still guards all divisions.
- **Cascade deletes:** Product -> joins cascade (steps/materials survive). Category -> products nullify (products survive). Step/Material -> joins cascade.
- **Marketing fee frequency:** `effectiveMarketing = marketingFee * percentSalesFromMarketing`. Handles Etsy offsite ads (15% on ~20% of sales = 3% effective).
- **Locked vs editable fees:** Platform-imposed fees are hardcoded constants on `PlatformType`. General: all editable. Etsy: all locked. Shopify/Amazon: platform+processing locked, marketing editable.
- **Template deduplication:** Shared WorkSteps and Materials matched by exact title string. Entity-level fields must be identical across templates sharing a title.
- **`portfolioPricing` vs `activePricing`:** Portfolio uses strict per-platform lookup; batch forecast uses best-available with platform-specific preference.
- **productSnapshot single-pass:** Traverses productWorkSteps and productMaterials once each, caching labor/material/hours. Uses raw-value `actualProfit` overload to avoid re-traversal.
- **Stopwatch accessible from detail view toolbar:** Timer button in WorkStepDetailView presents StopwatchView directly (2 taps from Labor tab), bypassing the edit form.
- **"Used By" products are tappable NavigationLinks** when viewed from library tabs (product == nil). Plain rows when viewed from product context.
- **Auto-navigation after creation:** Products, steps, and materials auto-navigate to their detail view after creation from any context (list, library, or template).
- **First-run experience:** Empty ProductListView shows prominent "Start from Template" CTA. After template application, auto-switches to Price tab to demonstrate profit analysis.
- **No CloudKit, no authentication, no sync.** Single-user, local-only.

---

## Future Features (Ranked by Customer Value)

### Tier 1 — Transformative (fills critical gaps)

| Priority | Feature | Status |
|----------|---------|--------|
| 1 | Sales & Order Tracking | Planned |
| 2 | Overhead & Fixed Cost Allocation | Planned |
| 3 | Reports & Data Export | Planned |
| 4 | Inventory & Stock Management | Planned |

**1. Sales & Order Tracking** — Log sales, dashboard with revenue/trends, per-product history. Turns calculator into business operating system.

**2. Overhead & Fixed Cost Allocation** — Track monthly fixed expenses, allocate per-unit, show "true total cost." The #1 pricing blind spot for makers.

**3. Reports & Data Export** — PDF cost sheets, CSV export, P&L summaries, tax-ready categorization.

**4. Inventory & Stock Management** — Track stock levels, auto-deduct, low stock alerts, shopping list adjusted for on-hand.

### Tier 2 — High Value Enhancements

| Priority | Feature | Status |
|----------|---------|--------|
| 5 | Custom Platform Profiles | Planned |
| 6 | Revenue Goals & Projections | Planned |
| 7 | Wholesale Pricing Tier | Planned |
| 8 | Production Time Analytics | Planned |

### Tier 3 — Polish & Differentiation

| Priority | Feature | Status |
|----------|---------|--------|
| 9 | Multi-Device Sync (CloudKit) | Planned |
| 10 | Craft Fair / POS Mode | Planned |
| 11 | Widgets & Quick Actions | Planned |
| 12 | Production Scheduling | Planned |
| 13 | Material Price Alerts | Planned |
