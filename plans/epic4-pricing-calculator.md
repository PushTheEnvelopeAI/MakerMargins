# Epic 4: Pricing Calculator & Profit Analysis

**Status:** In Progress
**Branch:** `epic_4` (from `main`)

## Context

Epics 1-3.5 delivered the full cost tracking engine: labor with shared work steps, materials with shared library items, shipping costs, and per-section buffers. The `totalProductionCost` is now accurate and live.

Epic 4 answers two maker questions:
1. **"What should I charge?"** — Target Price Calculator (COMPLETE)
2. **"What am I actually making?"** — Profit Analysis (PENDING)

The target price calculator was delivered first. Now makers need to enter what they actually charge (which differs from target due to market competition, efficiency gains, or platform strategy) and see their real profit per sale, including platform-specific shipping strategies and the labor-as-income insight for solo makers.

---

## Part 1: Target Price Calculator [COMPLETE]

> All sub-features below have been implemented and merged. Retained for reference.

### Schema Changes [COMPLETE]

#### ProductPricing (new model) [COMPLETE]
Per-product per-platform pricing overrides. Created lazily when user first visits a platform tab for a product, initialized from `PlatformFeeProfile` defaults.

| Property | Type | Notes |
|----------|------|-------|
| product | Product? | Many-to-one |
| platformType | PlatformType | Which platform tab this pricing is for |
| platformFee | Decimal | Platform fee % override (fraction). General only. Default: 0 |
| paymentProcessingFee | Decimal | Payment processing fee % override (fraction). General only. Default: 0 |
| marketingFee | Decimal | Marketing fee rate override (fraction). General/Shopify/Amazon. Default: 0 |
| percentSalesFromMarketing | Decimal | Fraction of sales from marketing/ads. Default: 0 |
| profitMargin | Decimal | Target profit margin (fraction). Default: 0.30 |

Cascade rules:
- Deleting a Product cascade-deletes its `ProductPricing` entries
- Up to 4 per product (one per PlatformType)

#### PlatformFeeProfile (modified — repurposed as universal defaults) [COMPLETE]
Single record storing user-configurable default values. Managed in Settings. Created lazily on first access.

Fields: `platformFee`, `paymentProcessingFee`, `marketingFee`, `percentSalesFromMarketing`, `profitMargin`

#### PlatformType (extension — hardcoded constants) [COMPLETE]
Added as extension on existing enum in `PlatformFeeProfile.swift`.

| Platform | Locked Platform Fee | Locked Processing Fee | Locked Processing Fixed | Locked Marketing |
|----------|--------------------|-----------------------|------------------------|------------------|
| General | nil (editable) | nil (editable) | $0 | nil (editable) |
| Etsy | 6.5% | 3% | $0.25 | 15% |
| Shopify | 0% | 2.9% | $0.30 | nil (editable) |
| Amazon | 15% | 0% | $0 | nil (editable) |

Plus editability flags, display helpers (fee description labels, SF Symbol icon names).

#### Product (modified) [COMPLETE]
- Added `@Relationship(deleteRule: .cascade) var productPricings: [ProductPricing] = []`

#### CostingEngine (target price functions) [COMPLETE]
- `effectiveMarketingRate(marketingFee:percentSalesFromMarketing:) -> Decimal`
- `resolvedFees(platformType:user...) -> 6-tuple`
- `targetRetailPrice(productionCost:...) -> Decimal?` (raw-value + model overloads)

### Sub-Features [ALL COMPLETE]

#### SF-1 — Schema Changes + CostingEngine Target Price Functions [COMPLETE]
- `Models/ProductPricing.swift` — created
- `Models/PlatformFeeProfile.swift` — repurposed as universal defaults + PlatformType extension
- `Models/Product.swift` — added productPricings relationship
- `MakerMarginsApp.swift` — added ProductPricing to Schema
- `Engine/CostingEngine.swift` — target price calculations
- All test makeContainer() helpers updated

#### SF-2 — Settings UI (Platform Pricing Defaults) [COMPLETE]
- `Views/Settings/PlatformPricingDefaultFormView.swift` — single universal defaults form
- `Views/Settings/SettingsView.swift` — "Selling" section with push to defaults form

#### SF-3 — PricingCalculatorView [COMPLETE]
- `Views/Products/PricingCalculatorView.swift` — tabbed calculator with platform picker, auto-pulled costs, locked/editable fee rows, target price hero output

#### SF-4 — Wire into ProductDetailView [COMPLETE]
- `Views/Products/ProductDetailView.swift` — PricingCalculatorView added to VStack

#### SF-5 — Product Duplication [COMPLETE]
- `Views/Products/ProductListView.swift` — duplicateProduct() copies ProductPricing entries

#### SF-6 — E2E Tests [COMPLETE]
- `MakerMarginsTests/Epic4Tests.swift` — 20 tests covering model CRUD, PlatformType constants, CostingEngine target price, duplication

### Editable vs Locked Fields Per Platform [COMPLETE]

| Field | General | Etsy | Shopify | Amazon |
|-------|---------|------|---------|--------|
| Platform Fee % | editable | locked (6.5%) | locked (0%) | locked (15%) |
| Payment Processing | editable | locked (3% + $0.25) | locked (2.9% + $0.30) | locked (0%) |
| Marketing Fee % | editable | locked (15%) | editable | editable |
| % Sales from Ads | editable | editable | editable | editable |
| Profit Margin % | editable | editable | editable | editable |

---

## Part 2: Profit Analysis [PENDING]

### Motivation

The target price calculator tells makers what they *should* charge. But makers often charge different prices — they may have adjusted for market competition, gotten more efficient with labor, or set platform-specific pricing strategies. They need to see what they're *actually* making.

Key scenarios:
- Different selling prices per platform (Etsy vs Amazon vs Shopify)
- Different shipping strategies: free shipping on Amazon, fixed shipping on Etsy (algorithm optimization), pass-through on Shopify
- Labor costs that represent the solo maker paying themselves (income, not expense) vs actual employee wages

### Schema Changes [PENDING]

#### ProductPricing — Add 2 fields
**File:** `MakerMargins/Models/ProductPricing.swift`

| New Property | Type | Default | Notes |
|---|---|---|---|
| `actualPrice` | `Decimal` | `0` | What the user actually charges on this platform |
| `actualShippingCharge` | `Decimal` | `0` | What the customer pays for shipping (0 = free shipping) |

Add to `init()` with default values. Non-breaking SwiftData change (additive with defaults).

No changes to `PlatformFeeProfile` — actual pricing is inherently per-product, not a global default.

### CostingEngine — New Functions [PENDING]

**File:** `MakerMargins/Engine/CostingEngine.swift`

New `// MARK: - Profit Analysis` section:

#### `productionCostExShipping(product:) -> Decimal`
Returns `totalLaborCostBuffered + totalMaterialCostBuffered` (no shipping). Needed because `totalProductionCost` bundles shipping in, but profit analysis requires separating production from shipping.

#### `totalSaleFees(actualPrice:actualShippingCharge:resolvedFees...) -> Decimal`
Platform + processing percentage fees applied to `actualPrice + actualShippingCharge` (the full customer payment). Marketing fees applied to `actualPrice` only (matches Etsy offsite ads behavior — ads don't apply to shipping). Fixed processing fee added per transaction.

```
grossRevenue = actualPrice + actualShippingCharge
transactionalFees = grossRevenue × (platformFee + processingFee)
marketingCost = actualPrice × effectiveMarketingRate
totalFees = transactionalFees + marketingCost + processingFixed
```

**Why fees on price+shipping:** Etsy charges 6.5% on item+shipping; Shopify processes 2.9% on total charge; Amazon referral covers total. Applying fees to price-only would understate costs by ~$0.50-$1.50 per sale.

#### `actualProfit(actualPrice:actualShippingCharge:productionCostExShipping:shippingCost:resolvedFees...) -> Decimal`
```
profit = (actualPrice + actualShippingCharge) - totalSaleFees - productionCostExShipping - shippingCost
```

#### `actualProfitMargin(profit:actualPrice:actualShippingCharge:) -> Decimal?`
Returns `profit / grossRevenue`, or `nil` if gross revenue is zero.

All functions also get model-based overloads (accepting `Product` + resolved fees) that delegate to raw-value versions.

### UI Design [PENDING]

#### Location
Extend `PricingCalculatorView` with a **second GroupBox** ("Profit Analysis") placed below the existing Target Price Calculator GroupBox. Same `pricingSurface` background. Shares the same `selectedPlatform` state — no duplicate platform tabs needed.

#### Layout

```
┌─ Target Price Calculator (existing) ─────────────────────┐
│  [General | Etsy | Shopify | Amazon]                      │
│  Production Cost / Shipping / Fees / Margin               │
│  Target Price          $42.50  (hero, accent)             │
└───────────────────────────────────────────────────────────┘

┌─ Profit Analysis ─────────────────────────────────────────┐
│  Your Actual Pricing   (section header, tertiary)         │
│    Selling Price       [$ _____]  (CurrencyInputField)    │
│    ─────                                                  │
│    Shipping Charge     [$ _____]  (CurrencyInputField)    │
│                                                           │
│  [Use Target Price ($42.50)]  ← only when price is empty  │
│                                                           │
│  ═══════ (only shown when actualPrice > 0) ═══════        │
│                                                           │
│  Breakdown             (section header, tertiary)         │
│    Revenue              $47.50  (price + shipping)        │
│    Platform Fees       -$3.09                             │
│    Processing Fees     -$1.67                             │
│    Marketing Fees      -$0.64                             │
│    Production Cost     -$20.80  (labor+material buffered) │
│    Shipping Expense    -$7.50   (maker's cost)            │
│    ─────                                                  │
│    Profit per Sale      $13.80  (hero, green/red)         │
│    Profit Margin         29.1%                            │
│                                                           │
│  ┌ Labor Callout (when labor > 0) ─────────────────────┐  │
│  │ Your labor ($8.40) is also your income.             │  │
│  │ Total take-home per sale: $22.20                    │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  ┌ Shipping Callout (absorbing costs) ─────────────────┐  │
│  │ You're absorbing $7.50 in shipping costs.           │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────┘

Footer: "Enter your actual selling price and shipping charge
to see your real profit per sale on this platform."
```

#### Interaction Details

- **"Use Target Price" button:** Shown when `actualPrice == 0` and `computedTargetPrice != nil`. Tapping pre-fills `actualPrice` with the target price. Explicit action, not auto-fill.
- **Breakdown visibility:** Only appears when `actualPrice > 0`. When zero, just show the two input fields.
- **Profit color:** Green (`AppTheme.Colors.accent`) when positive, `.red` when negative.
- **Fee breakdown:** Show Platform Fees, Processing Fees, and Marketing Fees as separate rows. Marketing row hidden when effective marketing is zero.
- **Labor callout:** Only shown when `totalLaborCostBuffered > 0` AND `actualPrice > 0`. Uses `AppTheme.Typography.note` with `.secondary` style. Shows `profit + laborCostBuffered` as take-home.
- **Shipping callout:** Only shown when `actualShippingCharge == 0` AND `product.shippingCost > 0`. Prevents confusion about why profit seems low with "free shipping."
- **Zero production cost:** Mirror the existing `emptyCostHint` pattern — show a warning when production cost is zero so users don't see misleading profit numbers.
- **Negative values:** Fee rows show negative amounts (e.g., "-$3.09"). Verify `CurrencyFormatter` handles negative `Decimal` correctly.

#### State Management (within existing PricingCalculatorView)

New `@State` properties:
```swift
@State private var actualPriceText: String = ""
@State private var actualShippingChargeText: String = ""
```

New `FocusableField` cases:
```swift
case actualPrice, actualShippingCharge
```

Extend `loadFieldTexts()` to populate these from `currentPricing`. Extend `handleFocusChange()` with two more entries. `onChange` for each text field writes back to `currentPricing?.actualPrice` / `currentPricing?.actualShippingCharge`.

### Product Duplication Update [PENDING]

**File:** `MakerMargins/Views/Products/ProductListView.swift` (line ~312-323)

Add `actualPrice` and `actualShippingCharge` to the `ProductPricing` copy in `duplicateProduct()`.

### Template Updates — Pre-populated Actual Pricing [PENDING]

Templates should include realistic actual prices so users immediately see a populated Profit Analysis section when they create from a template. This showcases the feature and teaches by example.

#### PricingTemplate — Add 2 fields
**File:** `MakerMargins/Engine/ProductTemplates.swift`

```swift
struct PricingTemplate {
    // ... existing fields ...
    let actualPrice: Decimal           // NEW -- realistic market price
    let actualShippingCharge: Decimal  // NEW -- platform-specific shipping charge
}
```

#### Template Actual Prices

Each template already has an Etsy `PricingTemplate`. Add actual prices that demonstrate realistic maker strategies (pricing below target for market competitiveness, various shipping approaches):

| Template | Actual Price | Shipping Charge | Approx Target | Strategy Demonstrated |
|---|---|---|---|---|
| Woodworking | $89.99 | $8.95 | ~$97 | Below target for competition, absorbing ~$3 shipping |
| 3D Printing | $49.99 | $5.50 | ~$58 | Below target, pass-through shipping (matches shippingCost) |
| Laser Coasters | $52.00 | $6.50 | ~$54 | Near target, slight shipping markup |
| Candle Making | $24.99 | $5.99 | ~$29 | Below target, absorbing ~$1.50 shipping |
| Resin Earrings | $22.00 | $4.50 | ~$27 | Below target, slight shipping markup |

#### TemplateApplier — Pass new fields
**File:** `MakerMargins/Engine/TemplateApplier.swift` (line ~83-91)

Update the `ProductPricing` creation in `apply()` to include `actualPrice` and `actualShippingCharge` from the template.

#### Why these values work for onboarding
- All templates price below target -- a common real-world scenario that motivates the "What am I actually making?" question
- Shipping strategies vary: some absorb costs (woodworking), some pass through (3D printing), some mark up slightly (laser)
- Users immediately see a profit breakdown with the labor callout, understanding the feature without needing to fill in any data

---

## Files to Modify (Part 2 — Profit Analysis)

| File | Changes | Status |
|------|---------|--------|
| `Models/ProductPricing.swift` | Add `actualPrice`, `actualShippingCharge` properties + init params | PENDING |
| `Engine/CostingEngine.swift` | Add `productionCostExShipping`, `totalSaleFees`, `actualProfit`, `actualProfitMargin` + model overloads | PENDING |
| `Engine/ProductTemplates.swift` | Add `actualPrice`, `actualShippingCharge` to `PricingTemplate` struct + all 5 template definitions | PENDING |
| `Engine/TemplateApplier.swift` | Pass new fields when creating `ProductPricing` from template | PENDING |
| `Views/Products/PricingCalculatorView.swift` | Add profit analysis GroupBox, 2 input fields, breakdown section, callouts | PENDING |
| `Views/Products/ProductListView.swift` | Update duplication to copy new fields | PENDING |
| `MakerMarginsTests/Epic4Tests.swift` | Add tests for new engine functions, model fields, duplication | PENDING |
| `MakerMarginsTests/Epic4_5Tests.swift` | Update template data integrity test to verify actualPrice > 0, update pricing creation test | PENDING |

No changes needed to: `PlatformFeeProfile`, `Product`, `MakerMarginsApp`, `ProductDetailView`, `ProductCostSummaryCard`, `AppTheme`, existing test files' `makeContainer()`.

---

## Implementation Phases (Part 2)

```
Phase 1: Schema + Engine + Templates
  |-- ProductPricing: add 2 fields (actualPrice, actualShippingCharge)
  |-- CostingEngine: add 4 functions + model overloads
  |-- PricingTemplate: add 2 fields + update all 5 template definitions
  +-- TemplateApplier: pass new fields through

Phase 2: UI  (depends on Phase 1)
  +-- PricingCalculatorView: profit analysis GroupBox

Phase 3: Duplication  (parallel with Phase 2)
  +-- ProductListView: update duplicateProduct()

Phase 4: Tests  (after Phase 1, can overlap with Phase 2)
  |-- Epic4Tests: ~10 new test cases for profit analysis
  +-- Epic4_5Tests: update template pricing tests for new fields
```

---

## Tests (Part 2 — Profit Analysis)

| # | Test | What it verifies | Status |
|---|------|-----------------|--------|
| 1 | `totalSaleFees` Etsy with shipping | Fees on price+shipping for platform/processing, price-only for marketing | PENDING |
| 2 | `totalSaleFees` zero shipping | Fees correct when shipping charge is $0 | PENDING |
| 3 | `actualProfit` positive | Known inputs produce expected positive profit | PENDING |
| 4 | `actualProfit` negative | Price too low results in negative profit | PENDING |
| 5 | `actualProfit` free shipping absorbed | Shipping charge $0, shipping cost $8, profit reflects the hit | PENDING |
| 6 | `actualProfitMargin` nil for zero revenue | Division guard works | PENDING |
| 7 | `actualProfitMargin` positive | Known profit / revenue produces correct % | PENDING |
| 8 | `productionCostExShipping` | Equals `totalProductionCost - shippingCost` | PENDING |
| 9 | `ProductPricing` CRUD with new fields | Create, persist, fetch back actualPrice and actualShippingCharge | PENDING |
| 10 | Duplication copies new fields | actualPrice and actualShippingCharge copied to duplicate | PENDING |
| 11 | Template PricingTemplate has actual prices | All templates have actualPrice > 0 and valid actualShippingCharge | PENDING |
| 12 | TemplateApplier creates pricing with actual fields | Apply template, verify ProductPricing has actualPrice and actualShippingCharge from template | PENDING |

---

## Verification (Part 2)

1. **CI:** Push to branch -> GitHub Actions: XcodeGen -> build -> all Epic 0-4.5 tests pass (including new profit tests)
2. **Manual (simulator):**
   - Create product with materials ($8.80), labor ($12.00), shipping ($7.50)
   - Open pricing calculator -> Etsy tab -> note target price
   - Scroll to Profit Analysis -> tap "Use Target Price" -> verify pre-fills
   - Enter $5 shipping charge -> verify breakdown shows all fee lines
   - Verify profit is positive, green hero display
   - Enter $0 shipping charge -> verify "absorbing $7.50" callout appears
   - Verify labor callout shows take-home amount
   - Switch to Amazon tab -> enter different actual price -> verify independent
   - Set actual price below cost -> verify negative profit in red
   - Close and reopen product -> verify actual pricing persisted
   - Duplicate product -> verify actual pricing copied
   - Create product from Woodworking template -> Etsy tab should show $89.99 selling price, $8.95 shipping
   - Profit Analysis section is pre-populated with breakdown -- no user input needed
   - Verify labor callout shows take-home amount
   - Create product from 3D Printing template -> verify different actual price ($49.99) and shipping ($5.50)

---

## CLAUDE.md Updates (after Part 2 implementation)

- Add `actualPrice` and `actualShippingCharge` to ProductPricing schema table
- Add profit analysis functions to Calculation Logic section
- Update PricingCalculatorView description in navigation structure
- Add acceptance criteria for the profit analysis feature
- Update PricingTemplate struct description in Key Decisions

---

## Key Design Decisions (Full Epic)

- **Tabbed by platform, not named profiles:** Fixed platform tabs with locked fees. Simpler UX, no profile management needed.
- **Marketing fee frequency model:** `effectiveMarketing = rate x % of sales`. Handles Etsy's offsite ads (15% on ~20% of sales = 3% effective).
- **PlatformFeeProfile as defaults store:** Single universal defaults record, not per-platform. Settings manages defaults; ProductPricing stores per-product overrides.
- **Locked platform fees:** Platform-imposed fees are hardcoded constants on `PlatformType`, not stored in any model.
- **Lazy creation pattern:** Both `PlatformFeeProfile` and `ProductPricing` created on first access.
- **Percentage display vs storage:** Users type "30" for 30%, model stores `0.30`.
- **Profit analysis in separate GroupBox:** Clear conceptual separation from target price ("what should I charge" vs "what am I making"). Shares platform tabs via same `selectedPlatform` state.
- **Fees on price + shipping:** Platform and processing fees apply to full customer payment (matching real Etsy/Shopify/Amazon behavior). Marketing fees on price only (matching Etsy offsite ads behavior).
- **Labor-as-income callout:** Solo makers' labor is their income, not a cost. Callout shows take-home = profit + labor to prevent panic-based mispricing.
- **"Use Target Price" button:** Explicit pre-fill action (not auto-fill) reduces friction while keeping control with the user.
- **Template actual prices:** All templates price below target, demonstrating the common real-world scenario and showcasing the profit analysis feature on first use.
- **No actual price defaults in PlatformFeeProfile:** Actual pricing is inherently per-product (a $15 candle and $85 cutting board from the same shop).
