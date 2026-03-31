# Epic 4: Target Price Calculator

**Status:** Planned
**Branch:** `epic_4` (from `main`)

## Context

Epics 1–3.5 delivered the full cost tracking engine: labor with shared work steps, materials with shared library items, shipping costs, and per-section buffers. The `totalProductionCost` is now accurate and live. Epic 4 answers the maker's next question: **"What should I charge?"**

The app needs a target price calculator that factors in platform-specific fees, marketing costs, and the maker's desired profit margin. Different selling platforms (Etsy, Shopify, Amazon) have different fee structures, and makers often sell on multiple platforms simultaneously. The calculator must account for this by providing platform-specific tabs with pre-filled, locked platform fees alongside user-configurable settings.

**Key changes from current state:**
- `PlatformFeeProfile` repurposed from "named profiles" to "defaults per platform type"
- New `ProductPricing` join model for per-product per-platform pricing overrides
- `CostingEngine` gets target retail price calculation functions
- Inline tabbed pricing calculator in `ProductDetailView`
- Settings gets platform pricing defaults management
- Marketing fee frequency model: `rate × % of sales` handles Etsy offsite ads and generalizes to other platforms

---

## Schema Changes

### ProductPricing (new model)
Per-product per-platform pricing overrides. Created lazily when user first visits a platform tab for a product, initialized from `PlatformFeeProfile` defaults.

| Property | Type | Notes |
|----------|------|-------|
| product | Product? | Many-to-one |
| platformType | PlatformType | Which platform tab this pricing is for |
| transactionFeePercentage | Decimal | Transaction fee % (fraction). General only. Default: 0 |
| fixedFeePerSale | Decimal | Fixed $ fee per sale. General only. Default: 0 |
| marketingFeeRate | Decimal | Marketing fee rate (fraction). Editable on General/Shopify/Amazon. Default: 0 |
| percentSalesFromMarketing | Decimal | Fraction of sales triggering marketing fee. All platforms. Default: 0 |
| profitMargin | Decimal | Target profit margin (fraction). All platforms. Default: 0.30 |

Cascade rules:
- Deleting a Product cascade-deletes its `ProductPricing` entries
- Up to 4 per product (one per PlatformType)

### PlatformFeeProfile (modified — repurposed as defaults)
Stores user-configurable default values per platform type. One per `PlatformType`, managed in Settings. Created lazily on first access.

- **Remove** `name: String`, `feePercentage: Decimal`, `marginGoal: Decimal`
- **Add** `transactionFeePercentage: Decimal` (default 0, General only)
- **Add** `fixedFeePerSale: Decimal` (default 0, General only)
- **Add** `marketingFeeRate: Decimal` (default 0)
- **Add** `percentSalesFromMarketing: Decimal` (default 0)
- **Add** `profitMargin: Decimal` (default 0.30)

### PlatformType (extension — hardcoded constants)
Added as extension on existing enum in `PlatformFeeProfile.swift`.

| Platform | Locked Transaction Fee | Locked Fixed Fee | Locked Marketing Rate |
|----------|----------------------|------------------|-----------------------|
| General | nil (editable) | nil (editable) | nil (editable) |
| Etsy | 0.095 (6.5% + 3%) | $0.45 ($0.20 + $0.25) | 0.15 (offsite ads) |
| Shopify | 0.029 (2.9%) | $0.30 | nil (editable) |
| Amazon | 0.15 (15% referral) | $0 | nil (editable) |

Plus editability flags, display helpers (fee description labels, SF Symbol icon names, marketing fee label per platform).

### Product (modified)
- **Add** `@Relationship(deleteRule: .cascade) var productPricings: [ProductPricing] = []`

### CostingEngine (modified — target price functions)
- **New formula:** `targetPrice = (productionCost + fixedFee) / (1 - (transactionFee + effectiveMarketing + profitMargin))`
- **Where:** `effectiveMarketing = marketingFeeRate × percentSalesFromMarketing`
- Returns `nil` when denominator ≤ 0 (fees + margin ≥ 100%)

---

## Editable vs Locked Fields Per Platform

| Field | General | Etsy | Shopify | Amazon |
|-------|---------|------|---------|--------|
| Transaction Fee % | editable | locked (9.5%) | locked (2.9%) | locked (15%) |
| Fixed Fee $ | editable | locked ($0.45) | locked ($0.30) | locked ($0) |
| Marketing Fee % | editable | locked (15%) | editable | editable |
| % Sales from Marketing | editable | editable | editable | editable |
| Profit Margin % | editable | editable | editable | editable |

---

## Sub-Features Checklist

### SF-1 — Schema Changes + CostingEngine Target Price Functions
**Goal:** Lay the data and calculation foundation. Everything downstream depends on this.

**Files to create:**
- `Models/ProductPricing.swift` — new join model (product, platformType, 5 pricing fields)

**Files to modify:**
- `Models/PlatformFeeProfile.swift`
  - Remove `name`, `feePercentage`, `marginGoal`
  - Add `transactionFeePercentage`, `fixedFeePerSale`, `marketingFeeRate`, `percentSalesFromMarketing`, `profitMargin`
  - Update `init()` accordingly
  - Add `PlatformType` extension with:
    - `lockedTransactionFee: Decimal?`, `lockedFixedFee: Decimal?`, `lockedMarketingFeeRate: Decimal?`
    - `isTransactionFeeEditable`, `isFixedFeeEditable`, `isMarketingFeeRateEditable`
    - `marketingFeeLabel: String` (Etsy: "% Sales from Offsite Ads", others: "% Sales from Marketing")
    - `lockedFeeDescriptions: [(label: String, value: String)]` for display
    - `iconName: String` (SF Symbol per platform)
- `Models/Product.swift`
  - Add `@Relationship(deleteRule: .cascade) var productPricings: [ProductPricing] = []`
  - Update `init()` — no new parameters needed (empty array default)
- `MakerMarginsApp.swift`
  - Add `ProductPricing.self` to Schema array
- `Engine/CostingEngine.swift`
  - Add `effectiveMarketingRate(marketingFeeRate:percentSalesFromMarketing:) -> Decimal`
  - Add `resolvedFees(platformType:userTransactionFee:userFixedFee:userMarketingFeeRate:userPercentSalesFromMarketing:userProfitMargin:)` — returns tuple with locked values applied
  - Add `targetRetailPrice(productionCost:transactionFee:fixedFee:marketingFeeRate:percentSalesFromMarketing:profitMargin:) -> Decimal?` (raw-value overload)
  - Add `targetRetailPrice(product:transactionFee:fixedFee:marketingFeeRate:percentSalesFromMarketing:profitMargin:) -> Decimal?` (model overload, computes productionCost from product)
- `MakerMarginsTests/Epic0Tests.swift` through `Epic3_5Tests.swift`
  - Add `ProductPricing.self` to each test's `makeContainer()` Schema array

---

### SF-2 — PlatformPricingDefaultsView + PlatformPricingDefaultFormView (Settings UI)
**Goal:** Settings UI for managing default pricing values per platform.

**Files to create:**
- `Views/Settings/PlatformPricingDefaultsView.swift` — list of 4 platform types, each pushing to form
- `Views/Settings/PlatformPricingDefaultFormView.swift` — editable defaults form per platform type

**Files to delete:**
- `Views/Settings/PlatformFeeProfileListView.swift` (empty stub, replaced)
- `Views/Settings/PlatformFeeProfileFormView.swift` (empty stub, replaced)

**Files to modify:**
- `Views/Settings/SettingsView.swift`
  - Change "Selling" section NavigationLink from `ContentUnavailableView` to `PlatformPricingDefaultsView()`
  - Update link label to "Platform Pricing Defaults"

**PlatformPricingDefaultsView structure:**
- `List` with `ForEach(PlatformType.allCases)` — each row: `Label(platform.rawValue, systemImage: platform.iconName)` + NavigationLink
- No add/delete — all 4 platform types always displayed
- `.scrollContentBackground(.hidden)` + `.appBackground()`

**PlatformPricingDefaultFormView structure:**
- `let platformType: PlatformType`
- Lazy creation: fetch or create `PlatformFeeProfile` for this platformType on appear
- **Read-only section** (if platform has locked fees): GroupBox showing locked fee descriptions as DetailRows
- **Editable section:** GroupBox with editable fields for this platform:
  - General: Transaction Fee %, Fixed Fee $, Marketing Fee %, % Sales from Marketing, Profit Margin %
  - Etsy: % Sales from Offsite Ads, Profit Margin %
  - Shopify/Amazon: Marketing Fee %, % Sales from Marketing, Profit Margin %
- Percentage fields: user types whole number (30), model stores fraction (0.30)
- Immediate save via `onChange` (same pattern as shipping cost in ProductDetailView)
- Footer: "These defaults pre-fill pricing for new products on [Platform]. Override per product in the Target Price Calculator."
- `.scrollContentBackground(.hidden)` + `.appBackground()`

---

### SF-3 — PricingCalculatorView (Inline Calculator in ProductDetailView)
**Goal:** Core pricing calculator — tabbed by platform, auto-pulls product costs, calculates target price.

**Files to modify:**
- `Views/Products/PricingCalculatorView.swift` (replace empty stub)

**Structure:**
- `let product: Product`
- `@Environment(\.modelContext)`, `@Environment(\.currencyFormatter)`
- `@State private var selectedPlatform: PlatformType = .general`
- `@State` text fields for each editable value + `@FocusState` enum for focus management

**Lazy creation logic:**
- Private helper `pricing(for: PlatformType) -> ProductPricing` — finds existing `ProductPricing` on product for that platform, or creates one initialized from `PlatformFeeProfile` defaults (or system defaults if no profile exists)
- Private helper `fetchOrCreateDefaults(for: PlatformType) -> PlatformFeeProfile` — finds or creates the defaults record

**Layout (GroupBox "Target Price Calculator"):**
1. **Segmented Picker** — `PlatformType.allCases`, `.pickerStyle(.segmented)`
2. **Your Costs** (auto-pulled, read-only):
   - DetailRow: "Material Cost" → `CostingEngine.totalMaterialCostBuffered(product:)`
   - DetailRow: "Labor Cost" → `CostingEngine.totalLaborCostBuffered(product:)`
   - DetailRow: "Shipping Cost" → `product.shippingCost`
   - DerivedRow: "Production Cost" → `CostingEngine.totalProductionCost(product:)`
3. **Platform Fees** (locked rows, shown for non-General tabs):
   - `ForEach(selectedPlatform.lockedFeeDescriptions)` as DetailRows
4. **Your Settings** (editable fields, vary by platform):
   - Shown based on editability flags from `PlatformType`
   - Percentage fields use decimal pad, suffix "%", whole-number display
   - Currency fields use `CurrencyInputField`
   - All fields use `.editableFieldStyle()`
5. **Effective Marketing** (derived, accent):
   - DerivedRow showing `effectiveMarketingRate` as percentage
6. **Target Price** (hero output):
   - Large, bold, accent color text
   - Shows formatted price or "—" with warning if fees + margin ≥ 100%

**@State reload on tab change:**
- `.onChange(of: selectedPlatform)` calls `loadFieldTexts()` to populate @State strings from the new platform's `ProductPricing`
- `.onAppear` also calls `loadFieldTexts()`
- `onChange` per text field writes back to `ProductPricing` model immediately

**Target price computed property:**
- Reads from current `ProductPricing` model values (not text fields)
- Calls `CostingEngine.resolvedFees(...)` then `CostingEngine.targetRetailPrice(...)`
- SwiftUI reactivity auto-updates when model changes

---

### SF-4 — Wire PricingCalculatorView into ProductDetailView
**Goal:** Add the calculator to the product scroll.

**Files to modify:**
- `Views/Products/ProductDetailView.swift`
  - Add `PricingCalculatorView(product: product)` to VStack after `shippingSection`:
  ```swift
  VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
      headerSection
      ProductCostSummaryCard(product: product).padding(.horizontal)
      laborSection
      materialsSection
      shippingSection
      PricingCalculatorView(product: product)   // NEW
  }
  ```

---

### SF-5 — Product Duplication Update
**Goal:** Duplicated products copy pricing overrides.

**Files to modify:**
- `Views/Products/ProductListView.swift`
  - In `duplicateProduct()`, after material re-linking loop, add loop to copy `ProductPricing` entries:
    - For each `srcPricing in source.productPricings`: create new `ProductPricing` with same field values, linked to the copy
    - Insert into modelContext

---

### SF-6 — E2E Tests
**Goal:** Comprehensive test coverage for Epic 4.

**Files to modify:**
- `MakerMarginsTests/Epic4Tests.swift` (replace stub)

**Tests (13 total):**

*Model CRUD (4):*
1. Create PlatformFeeProfile with all new fields — persist, fetch, verify all properties
2. Create ProductPricing linked to Product — persist, fetch, verify fields and relationship
3. Delete Product → cascade-deletes ProductPricing entries, PlatformFeeProfile survives
4. Same product, General + Etsy ProductPricing — change profit margin on General, verify Etsy unchanged

*PlatformType constants (3):*
5. Etsy locked fees correct — `lockedTransactionFee == 0.095`, `lockedFixedFee == 0.45`, `lockedMarketingFeeRate == 0.15`
6. General has no locked fees — all three return nil
7. Editability flags — `isTransactionFeeEditable` true only for General, `isMarketingFeeRateEditable` false only for Etsy, etc.

*CostingEngine calculations (5):*
8. `effectiveMarketingRate` — `0.15 × 0.20 = 0.03`
9. `targetRetailPrice` General — product with known production cost, General fees, verify expected output
10. `targetRetailPrice` Etsy — same product, Etsy locked fees, verify expected output
11. `targetRetailPrice` returns nil — fees + margin ≥ 100%
12. `resolvedFees` — call with Etsy + user values differing from locked → verify locked values used for transaction/fixed/marketing, user values used for percentSalesFromMarketing and profitMargin

*Product duplication (1):*
13. Duplicate product with General ProductPricing — verify copy has matching field values, is a distinct object, changes to copy don't affect original

---

## Key Design Decisions

- **Tabbed by platform, not named profiles:** The original spec had user-created named profiles ("My Etsy Shop"). The new design uses fixed platform tabs with locked fees. Simpler UX, no profile management needed. Users who sell on multiple shops of the same platform use the same fees anyway.
- **Marketing fee frequency model:** `effectiveMarketing = rate × % of sales`. Handles Etsy's offsite ads (15% on ~20% of sales = 3% effective). Generalizes to Shopify/Amazon where users enter their own ad cost rate and conversion frequency. Avoids the complexity of modeling monthly ad budgets with sales volume estimates.
- **PlatformFeeProfile as defaults store:** Repurposed from named profiles to one-per-platform defaults. Keeps the existing SwiftData model (already in Schema) but changes its purpose. Settings UI manages defaults; ProductPricing stores per-product overrides.
- **Locked platform fees:** Platform-imposed fees are hardcoded constants on `PlatformType`, not stored in any model. This ensures accuracy (users can't accidentally change them) and simplifies the model. Only user-configurable values are persisted.
- **Lazy creation pattern:** Both `PlatformFeeProfile` (defaults) and `ProductPricing` (overrides) are created on first access, not eagerly. Avoids creating records for platforms the user never uses.
- **Percentage display vs storage:** Users type "30" for 30%, model stores `0.30`. Consistent with existing buffer fields (laborBuffer, materialBuffer). All conversion happens at the view boundary.
- **No profit breakdown or sale tracking in this epic.** Focused scope: target price only. Profit analysis, shipping strategy, and sale tracking are future features that build on this foundation.

---

## Key Technical Notes

- **SwiftData enum predicates:** `#Predicate` may not support `PlatformType` enum comparison directly. If the compiler rejects it, add a `platformTypeRaw: String` stored property to both `PlatformFeeProfile` and `ProductPricing` with computed `platformType` getter/setter. Use the raw string in predicates.
- **Schema migration:** Removing `name`, `feePercentage`, `marginGoal` from `PlatformFeeProfile` is a breaking change. Acceptable pre-release — no production data. SwiftData lightweight migration handles added fields with defaults.
- **Test schema updates:** All existing test files (Epic0–3.5) need `ProductPricing.self` added to their `makeContainer()` Schema arrays so the ModelContainer includes the full schema.
- **`resolvedFees` centralizes locked vs user logic:** Both the UI and CostingEngine use this function. No duplicated "which value to use" logic.
- **Percentage input fields:** Need clear-on-focus (clear "0" when tapped) and restore-on-blur (restore "0" when left empty) behavior, matching existing patterns in WorkStepFormView and ProductDetailView shipping field.

---

## Phase Sequencing

```
SF-1 (Schema + Engine)                    ← foundation, everything depends on this
  │
  ├── SF-2 (Settings UI)                  ← needs PlatformFeeProfile model
  │
  ├── SF-3 (PricingCalculatorView)        ← needs ProductPricing model + CostingEngine
  │     │
  │     └── SF-4 (ProductDetailView wire) ← needs PricingCalculatorView
  │
  ├── SF-5 (Product duplication)          ← needs ProductPricing model
  │
  └── SF-6 (Tests)                        ← write incrementally, finalize at end
```

SF-2, SF-3, and SF-5 can be done in parallel after SF-1. SF-4 depends on SF-3. SF-6 spans the entire epic.

---

## Verification

1. **CI:** Push to `epic_4` → GitHub Actions: XcodeGen → build → all Epic0–4 tests pass
2. **Manual (simulator):**
   - Open Settings → Platform Pricing Defaults → configure Etsy defaults (20% marketing sales, 30% profit)
   - Create a product with materials ($8.80), labor ($12.00), shipping ($5.00)
   - Scroll to Target Price Calculator → verify Production Cost auto-pulls correctly
   - **Etsy tab:** Locked fees shown (9.5% + $0.45 + 15%). Editable: % Sales from Offsite Ads (pre-filled from defaults), Profit Margin. Target price calculates.
   - **General tab:** All fields editable. Enter custom fees. Target price updates live.
   - **Shopify tab:** Locked 2.9% + $0.30. Marketing and profit editable.
   - Change profit margin on Etsy tab → switch to General tab → verify General's margin unchanged (per-product per-platform independence)
   - Close and reopen product → verify overrides persisted
   - Duplicate product → verify pricing overrides copied to new product
   - Set fees + margin to ≥ 100% → verify "—" warning instead of impossible price
