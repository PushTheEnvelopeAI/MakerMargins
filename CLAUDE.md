# MakerMargins — Shop Intelligence App
## Persistent Architecture & Engineering Reference

This file is the source of truth for Claude Code across all sessions. Update it as the project evolves.

---

## Project Overview

**App Name:** MakerMargins
**Purpose:** iOS app for makers (woodworkers, crafters, small-scale manufacturers) to track SKU-level labor and material costs, calculate true cost of goods sold, and generate data-driven retail pricing.

**Tech Stack**
- Language: Swift
- Framework: SwiftUI (Liquid Glass design system — iOS 26 native)
- Database: SwiftData
- Testing: XCTest / Swift Testing (E2E regression per Epic)
- Target Platform: iOS
- Minimum Deployment Target: **iOS 26**
- Distribution: Single-user, local SwiftData only (no CloudKit sync)
- Currency: USD by default; EUR available via user setting. Format all monetary `Decimal` values through a shared `CurrencyFormatter` that respects the user's selection.

**Deployment Target Rationale**
iOS 26 is the minimum. The Liquid Glass design language is a first-class iOS 26 system behavior (materials, specular layering, adaptive chrome) — backporting it to earlier OS versions would require significant custom work that has no business value for a greenfield app. As of March 2026, iOS 26 adoption among active iPhone users is sufficient for a new App Store release. SwiftData's most stable relationship APIs also require iOS 17+, and iOS 26 gives us the full modern stack without workarounds.

---

## Development Roadmap

| Epic | Scope | Status |
|------|-------|--------|
| 0 | Infrastructure — Repo, SwiftData models, Navigation shell, Design Sprint, CLAUDE.md | In Progress |
| 1 | Product & Category Management + E2E Tests | Pending |
| 2 | Labor Engine & Stopwatch + E2E Tests | Pending |
| 3 | Material Ledger & Costing + E2E Tests | Pending |
| 4 | Pricing Calculator & Platform Tabs + E2E Tests | Pending |
| 5 | Batch Forecasting Widgets + E2E Tests | Pending |
| 6 | Production Readiness & App Store Launch | Pending |

---

## Core Schema (Source of Truth)

### Product
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| title | String | |
| description | String | |
| image | Data? | Optional image blob |
| shippingCost | Decimal | Per-unit shipping cost |
| materialBuffer | Decimal | % buffer (e.g. 0.10 = 10%) |
| laborBuffer | Decimal | % buffer (e.g. 0.05 = 5%) |
| category | Category? | Many-to-one |
| workSteps | [WorkStep] | One-to-many |
| materials | [Material] | One-to-many |

### Category
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| name | String | |
| products | [Product] | One-to-many (inverse) |

### WorkStep
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| title | String | |
| description | String | |
| image | Data? | Optional |
| laborRate | Decimal | $/hour |
| recordedTime | TimeInterval | Seconds — time to complete batch |
| batchUnitsCompleted | Decimal | How many units made in that recording |
| unitName | String | e.g. "piece", "board", "item" |
| unitsRequiredPerProduct | Decimal | How many of this step per finished product |
| product | Product | Many-to-one (inverse) |

### Material
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| title | String | |
| description | String | |
| bulkCost | Decimal | Total cost of bulk purchase |
| bulkQuantity | Decimal | Number of units in bulk purchase |
| unitName | String | e.g. "oz", "board-foot", "sheet" |
| unitsRequiredPerProduct | Decimal | How many units consumed per product |
| product | Product | Many-to-one (inverse) |

### PlatformFeeProfile
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| name | String | User-facing label (e.g. "My Etsy Shop") |
| platformType | Enum | General / Etsy / Shopify / Amazon |
| feePercentage | Decimal | Platform transaction + listing fee % |
| marginGoal | Decimal | Target profit margin % |

> Fee structure details (default rates per platform, whether fees are editable) will be defined in Epic 4.

---

## Calculation Logic (The Math)

All calculations should be implemented as computed properties on their respective models or in a dedicated `CostingEngine` handler.

```
// WorkStep level
unitTime = recordedTime / batchUnitsCompleted           // seconds per unit
unitTimeHours = unitTime / 3600                         // convert to hours for rate multiplication

// Product Labor (per WorkStep)
// laborRate is $/hour — MUST divide seconds by 3600 before multiplying
stepLaborCost = (unitTimeHours * unitsRequiredPerProduct) * laborRate

// Product total labor
totalLaborCost = sum of stepLaborCost across all WorkSteps

// Material level
materialUnitCost = bulkCost / bulkQuantity

// Product Material (per Material)
materialLineCost = materialUnitCost * unitsRequiredPerProduct

// Product total material
totalMaterialCost = sum of materialLineCost across all Materials

// Total Production Cost
totalProductionCost = (totalLaborCost + totalMaterialCost + shippingCost)
                      * (1 + materialBuffer + laborBuffer)

// Target Retail Price (given a PlatformFeeProfile)
targetRetailPrice = totalProductionCost / (1 - (feePercentage + marginGoal))
```

---

## Directory Layout

```
MakerMargins/                              ← repo root
├── CLAUDE.md                              ← this file
│
├── MakerMargins/                          ← main app target
│   ├── MakerMarginsApp.swift              ← @main entry point, ModelContainer setup
│   ├── ContentView.swift                  ← 3-tab TabView shell (Products | Workshop | Settings)
│   │
│   ├── Models/                            ← SwiftData @Model types
│   │   ├── Product.swift
│   │   ├── Category.swift
│   │   ├── WorkStep.swift
│   │   ├── Material.swift
│   │   └── PlatformFeeProfile.swift
│   │
│   ├── Engine/                            ← calculation & formatting logic
│   │   ├── CostingEngine.swift            ← all costing/pricing computed logic
│   │   └── CurrencyFormatter.swift        ← shared USD/EUR display formatter
│   │
│   └── Views/                             ← SwiftUI views, grouped by feature
│       ├── Products/                      ← Tab 1 root + all product-owned views
│       │   ├── ProductListView.swift      ← Tab 1 root (NavigationStack)
│       │   ├── ProductDetailView.swift    ← scrollable hub: cost summary + inline sections
│       │   ├── ProductFormView.swift      ← create/edit sheet
│       │   ├── ProductCostSummaryCard.swift ← reusable cost breakdown card
│       │   ├── PricingCalculatorView.swift  ← inline section in ProductDetailView
│       │   └── BatchForecastView.swift      ← inline section in ProductDetailView
│       ├── Workshop/                      ← Tab 2: active production
│       │   └── WorkshopView.swift         ← flat cross-product WorkStep list → stopwatch
│       ├── Labor/
│       │   ├── WorkStepListView.swift     ← inline content in ProductDetailView
│       │   ├── WorkStepDetailView.swift   ← pushed from Products tab or Workshop tab
│       │   ├── WorkStepFormView.swift     ← create/edit sheet
│       │   └── StopwatchView.swift        ← fullScreenCover from WorkStepDetailView
│       ├── Materials/
│       │   ├── MaterialListView.swift     ← inline content in ProductDetailView
│       │   ├── MaterialDetailView.swift   ← pushed from ProductDetailView
│       │   └── MaterialFormView.swift     ← create/edit sheet
│       ├── Categories/
│       │   ├── CategoryListView.swift     ← pushed from SettingsView
│       │   └── CategoryFormView.swift     ← create/edit sheet
│       └── Settings/                      ← Tab 3 root + config views
│           ├── SettingsView.swift         ← Tab 3 root: currency toggle + nav rows
│           ├── PlatformFeeProfileListView.swift ← pushed from SettingsView
│           └── PlatformFeeProfileFormView.swift ← create/edit sheet
│
├── MakerMarginsTests/                     ← unit & integration tests (XCTest / Swift Testing)
│   ├── Epic0Tests.swift
│   ├── Epic1Tests.swift
│   ├── Epic2Tests.swift
│   ├── Epic3Tests.swift
│   ├── Epic4Tests.swift
│   └── Epic5Tests.swift
│
└── MakerMarginsUITests/                   ← UI automation (XCUITest)
    └── MakerMarginsUITests.swift
```

---

## Navigation Structure

**3-Tab TabView.** ContentView owns only the TabView — no state, no queries. Each tab root owns its own `NavigationStack`.

| Tab | Root View | SF Symbol |
|-----|-----------|-----------|
| 1 | `ProductListView` | `square.grid.2x2` |
| 2 | `WorkshopView` | `timer` |
| 3 | `SettingsView` | `gearshape` |

### Tab 1 — Products (primary workspace)
```
ProductListView                            [ROOT]
└── [push] ProductDetailView               [Level 1 — scrollable hub with DisclosureGroup sections]
    │   Cost Summary (ProductCostSummaryCard)
    │   Labor section (inline WorkStepListView content)
    │   Materials section (inline MaterialListView content)
    │   Pricing section (inline PricingCalculatorView content)
    │   Forecast section (inline BatchForecastView content)
    ├── [push] WorkStepDetailView          [Level 2]
    │   └── [fullScreenCover] StopwatchView  [Level 3 — MAX DEPTH]
    ├── [push] MaterialDetailView          [Level 2]
    ├── [sheet] ProductFormView            [create / edit]
    ├── [sheet] WorkStepFormView           [create / edit]
    └── [sheet] MaterialFormView           [create / edit]
```

### Tab 2 — Workshop (active production, speed to stopwatch)
```
WorkshopView                              [ROOT — flat list of all steps across all products]
└── [push] WorkStepDetailView             [Level 1]
    └── [fullScreenCover] StopwatchView   [Level 2]
```
**Stopwatch tap count:** 2 taps from Workshop tab (tap step row → tap Start). This is the fastest path for a maker mid-production.

### Tab 3 — Settings (one-time config)
```
SettingsView                              [ROOT — currency toggle inline]
├── [push] PlatformFeeProfileListView     [Level 1]
│   ├── [sheet] PlatformFeeProfileFormView  [create / edit]
└── [push] CategoryListView               [Level 1]
    └── [sheet] CategoryFormView          [create / edit]
```

### ContentView skeleton
```swift
TabView {
    NavigationStack { ProductListView() }
        .tabItem { Label("Products", systemImage: "square.grid.2x2") }
    NavigationStack { WorkshopView() }
        .tabItem { Label("Workshop", systemImage: "timer") }
    NavigationStack { SettingsView() }
        .tabItem { Label("Settings", systemImage: "gearshape") }
}
```

---

## Architecture Conventions

- **SwiftData** models live in `Models/` and use `@Model` macro.
- **Views** live in `Views/` organized by feature (e.g. `Views/Products/`, `Views/Labor/`).
- **Logic/Engines** live in `Engine/` (e.g. `CostingEngine.swift`).
- **Tests** live in `MakerMarginsTests/` — one test file per Epic, named `EpicNTests.swift`.
- All monetary values use `Decimal` (never `Double`) to avoid floating-point drift.
- `TimeInterval` (seconds as `Double`) is acceptable for time tracking. The `/ 3600` hours conversion is part of the `CostingEngine` formula — it is NOT done at the model layer. This prevents silent unit errors.
- Buffers are stored as decimal fractions (0.10 = 10%) not percentages.

---

## Key Decisions & Notes

- Labor rate is stored on the **WorkStep**, not the Product, to support mixed-skill workflows (e.g. machining at $25/hr vs. finishing at $15/hr).
- `batchUnitsCompleted` on WorkStep allows a single timed session to cover multiple units, which is the core "batch tracking" feature.
- PlatformFeeProfiles are global (not per-product) so the user can quickly compare prices across platforms on the Pricing Calculator screen. Each profile has a `name` field to allow multiple profiles of the same platform type.
- Image storage uses `Data?` blobs in SwiftData for simplicity in Epic 0; migrate to file-system URLs in Epic 6 if performance requires it.
- Currency is USD by default. A user-level setting switches to EUR. All display formatting goes through `CurrencyFormatter`; stored `Decimal` values are always in the user's chosen currency (no conversion logic needed for v1).
- Navigation structure decided in Epic 0 design sprint: 3-tab TabView (Products | Workshop | Settings). See Navigation Structure section above.
- Single-user app. No CloudKit, no authentication, no sync in scope.
