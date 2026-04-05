# Epic Acceptance Criteria Archive

Completed acceptance criteria for Epics 1–6. All features implemented and verified.
Extracted from CLAUDE.md during the production readiness refactor to reduce the main reference file to actionable content only.

---

## Epic 1 — Product & Category Management ✅

**Product CRUD**
- [x] User can create a Product (title, summary, shippingCost, materialBuffer, laborBuffer, optional category)
- [x] User can view a list of all Products on ProductListView
- [x] User can tap a Product to open ProductDetailView
- [x] User can edit a Product via ProductFormView
- [x] User can delete a Product (with confirmation); its associations are cascade-deleted

**Category CRUD**
- [x] User can create Categories inline from the product form's category picker
- [x] User can assign a Category when creating/editing a Product
- [x] Deleting a Category does NOT delete its Products (products become uncategorised)

**Currency, Appearance, Duplication**
- [x] USD / EUR toggle in Settings; CurrencyFormatter used everywhere
- [x] System / Light / Dark appearance picker with persistence
- [x] Product duplication via context menu with "(Copy)" suffix

**Tests: 14 in Epic1Tests.swift**

---

## Epic 2 — Labor Engine & Stopwatch ✅

- [x] WorkStep CRUD with shared entities via ProductWorkStep join model
- [x] Multi-select picker to add existing steps; "Used By" section shows linked products
- [x] Reorderable steps per product with persisted sortOrder
- [x] Full-screen stopwatch with pause/resume/save/discard/re-record
- [x] CostingEngine: unitTimeHours, stepLaborCost, totalLaborCost, totalProductionCost
- [x] Default labor rate in Settings, pre-fills new associations
- [x] Labor tab as searchable step library

**Tests: 13 in Epic2Tests.swift**

---

## Epic 3 — Material Ledger & Costing ✅

- [x] Material CRUD with shared entities via ProductMaterial join model
- [x] Multi-select picker; "Used By" section; reorderable per product
- [x] CostingEngine: materialUnitCost, materialLineCost, totalMaterialCost
- [x] Per-section buffers: labor × (1 + laborBuffer) + material × (1 + materialBuffer) + shipping
- [x] Materials tab as searchable material library

**Tests: 13 in Epic3Tests.swift**

---

## Epic 3.5 — Item vs Product Cost Separation ✅

- [x] "One Item, One Number" — WorkStep = Hours/Unit, Material = Cost/Unit (item-level)
- [x] laborRate moved from WorkStep to ProductWorkStep join model
- [x] Simplified forms (no rate/units on item forms; product settings in detail view)
- [x] Library tabs show item-level metrics; product context shows product-level costs

**Tests: 13 in Epic3_5Tests.swift**

---

## Epic 4 — Pricing Calculator & Profit Analysis ✅

- [x] PlatformFeeProfile (universal defaults) + PlatformType locked fee constants
- [x] ProductPricing (per-product per-platform overrides, created lazily)
- [x] Target Price Calculator: resolvedFees, targetRetailPrice, segmented platform tabs
- [x] Profit Analysis: actual price/shipping inputs, fee breakdown, earnings hero, hourly rate
- [x] "Use Target Price" button, shipping absorbed callout, zero-cost warning
- [x] Settings pricing defaults form; product duplication copies pricing

**Tests: 37 in Epic4Tests.swift**

---

## Epic 4.5 — Template Products ✅

- [x] 5 templates: Woodworking, 3D Printing, Laser Engraving, Candle Making, Resin Art
- [x] Pure Swift structs in ProductTemplates.swift; TemplateApplier with title-based dedup
- [x] 42 bundled images in Assets.xcassets
- [x] Template picker (2-column grid) from "+" menu; auto-navigate after application

**Tests: 17 in Epic4_5Tests.swift**

---

## Epic 5 — Batch Forecasting Calculator ✅

- [x] Batch size input with +/- and quick-select chips (5/10/25/50/100)
- [x] Labor Time Forecast, Material Shopping List, Revenue Forecast sections
- [x] bulkPurchasesNeeded with ceiling division and leftover tracking
- [x] Revenue section conditional on actualPrice > 0; batch earnings hero

**Tests: 23 in Epic5Tests.swift**

---

## Epic 6 — Portfolio Metrics & Product Comparison ✅

- [x] ProductSnapshot struct; portfolioPricing, productSnapshot, portfolioSnapshots, portfolioAverages
- [x] Platform picker + sort picker (Earnings/Margin/$/Hour/Cost)
- [x] Summary card, earnings leaderboard, profitability rankings, cost breakdown stacked bars
- [x] All products tappable NavigationLinks; empty states for no products/no pricing

**Tests: 21 in Epic6Tests.swift**
