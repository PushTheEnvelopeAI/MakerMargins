# Epic 5 — Batch Forecasting Calculator

## Context

A maker preparing for a craft fair thinks: "I want to bring 20 cutting boards." Today they'd need a spreadsheet to answer: How many hours will that take? How much of each material do I need to buy? What's my total investment? What's my projected revenue? Epic 5 replaces the stub in the Forecast sub-tab of `ProductDetailView` with a single-input batch calculator that answers all four questions from one number — the batch size.

The feature is purely computational — no new models, no persistence. The maker enters a quantity, and every section updates live. The "killer feature" is the **Material Shopping List** with purchase recommendations: "Buy 3 × 32 oz Mineral Oil — 6 oz leftover." This is something no simple spreadsheet gives you without custom formulas.

---

## Files to Create

None. All changes are modifications to existing files.

## Files to Modify

| File | Change |
|------|--------|
| `MakerMargins/Engine/CostingEngine.swift` | Add `// MARK: - Batch Forecasting (Epic 5)` section with ~15 new static functions |
| `MakerMargins/Views/Products/BatchForecastView.swift` | Replace stub with full calculator implementation (~300 lines) |
| `MakerMarginsTests/Epic5Tests.swift` | Replace stub with full test suite (~22 tests) |
| `CLAUDE.md` | Update Epic 5 status, add batch formulas to Calculation Logic, add acceptance criteria |

No model changes. No schema migration. No new design tokens. No changes to `ProductDetailView.swift` (it already wires `BatchForecastView(product: product)` in the Forecast tab content).

---

## Step 1: CostingEngine Batch Functions (`Engine/CostingEngine.swift`)

Add a new `// MARK: - Batch Forecasting (Epic 5)` section at the end of the existing `CostingEngine` enum. All functions follow the established pattern: static, pure, model-based + raw-value overloads.

### Labor Time Functions

```swift
/// Labor hours for a single step across the entire batch.
static func batchStepHours(link: ProductWorkStep, batchSize: Int) -> Decimal

/// Raw-value overload.
static func batchStepHours(laborHoursPerProduct: Decimal, batchSize: Int) -> Decimal
// → laborHoursPerProduct * Decimal(batchSize)

/// Total labor hours for all steps across the entire batch.
static func batchLaborHours(product: Product, batchSize: Int) -> Decimal

/// Raw-value overload.
static func batchLaborHours(totalLaborHoursPerUnit: Decimal, batchSize: Int) -> Decimal
// → totalLaborHoursPerUnit * Decimal(batchSize)
```

### Material Shopping List Functions

```swift
/// Units of a single material needed for the entire batch.
static func batchMaterialUnits(link: ProductMaterial, batchSize: Int) -> Decimal

/// Raw-value overload.
static func batchMaterialUnits(unitsRequiredPerProduct: Decimal, batchSize: Int) -> Decimal
// → unitsRequiredPerProduct * Decimal(batchSize)

/// Cost of a single material line across the entire batch (before buffer).
static func batchMaterialLineCost(link: ProductMaterial, batchSize: Int) -> Decimal

/// Raw-value overload.
static func batchMaterialLineCost(materialLineCostPerUnit: Decimal, batchSize: Int) -> Decimal
// → materialLineCostPerUnit * Decimal(batchSize)

/// Number of bulk purchases required to fulfill a batch's material needs.
/// Uses ceiling division. Returns 0 purchases if bulkQuantity is zero.
/// Tuple: (purchases: Int, totalBulkUnits: Decimal, leftover: Decimal)
static func bulkPurchasesNeeded(
    unitsNeeded: Decimal,
    bulkQuantity: Decimal
) -> (purchases: Int, totalBulkUnits: Decimal, leftover: Decimal)
// purchases = Int(ceil(unitsNeeded / bulkQuantity))
// totalBulkUnits = Decimal(purchases) * bulkQuantity
// leftover = totalBulkUnits - unitsNeeded

/// Total cost to purchase enough bulk units.
static func batchPurchaseCost(purchases: Int, bulkCost: Decimal) -> Decimal
// → Decimal(purchases) * bulkCost
```

### Batch Cost Summary Functions

```swift
/// Total production cost for the entire batch (with buffers and shipping).
static func batchProductionCost(product: Product, batchSize: Int) -> Decimal

/// Raw-value overload.
static func batchProductionCost(totalProductionCostPerUnit: Decimal, batchSize: Int) -> Decimal
// → totalProductionCostPerUnit * Decimal(batchSize)

/// Cost per unit within a batch (should equal single-unit production cost).
/// Returns 0 if batchSize is zero.
static func batchCostPerUnit(batchProductionCost: Decimal, batchSize: Int) -> Decimal
// → batchProductionCost / Decimal(batchSize)
```

### Batch Revenue Functions

```swift
/// Gross revenue for the entire batch.
static func batchRevenue(
    actualPrice: Decimal,
    actualShippingCharge: Decimal,
    batchSize: Int
) -> Decimal
// → (actualPrice + actualShippingCharge) * Decimal(batchSize)

/// Total platform fees for the entire batch.
/// Each sale is an independent transaction — fixed fees apply per sale.
static func batchTotalFees(
    actualPrice: Decimal,
    actualShippingCharge: Decimal,
    platformFee: Decimal,
    paymentProcessingFee: Decimal,
    paymentProcessingFixed: Decimal,
    marketingFee: Decimal,
    percentSalesFromMarketing: Decimal,
    batchSize: Int
) -> Decimal
// → totalSaleFees(...) * Decimal(batchSize)

/// Total profit for the entire batch.
static func batchProfit(
    actualPrice: Decimal,
    actualShippingCharge: Decimal,
    productionCostExShipping: Decimal,
    shippingCost: Decimal,
    platformFee: Decimal,
    paymentProcessingFee: Decimal,
    paymentProcessingFixed: Decimal,
    marketingFee: Decimal,
    percentSalesFromMarketing: Decimal,
    batchSize: Int
) -> Decimal
// → actualProfit(...) * Decimal(batchSize)
```

### Formatting

```swift
/// Formats Decimal hours to a human-readable "Xh Ym" string.
/// Drops seconds for batch-level display. 0.5 → "0h 30m", 4.75 → "4h 45m"
static func formatHoursReadable(_ hours: Decimal) -> String
// Convert hours to seconds, then extract h/m components
```

---

## Step 2: BatchForecastView (`Views/Products/BatchForecastView.swift`)

Replace the stub with a full calculator. Reuses existing UI components from `ViewModifiers.swift` and follows the same GroupBox + section layout as `PricingCalculatorView`.

### State

```swift
struct BatchForecastView: View {
    let product: Product

    @State private var batchSize: Int = 10
    @State private var batchSizeText: String = "10"
    @Environment(\.currencyFormatter) private var formatter
}
```

Batch size is **session state only** — not persisted. This is a calculator, not a production plan. Default of 10 gives meaningful numbers on first view (batch of 1 would just repeat the Build tab's data).

### Body Layout (top to bottom)

```
ScrollView (.appBackground not needed — parent in ProductDetailView handles it)
└── VStack(spacing: AppTheme.Spacing.lg)
    ├── batchSizeInput          // always visible
    ├── laborTimeForecast       // hidden if no work steps
    ├── materialShoppingList    // hidden if no materials
    ├── batchCostSummary        // always visible
    ├── revenueForecast         // hidden if no pricing with actualPrice > 0
    └── emptyProductHint        // only when no steps AND no materials
```

### Section 1: Batch Size Input

```
GroupBox {
    VStack(spacing: AppTheme.Spacing.sm) {
        Text("How many are you making?")           // .sectionHeader
        HStack {
            Button("-") { batchSize = max(1, batchSize - 1) }
            TextField("", text: $batchSizeText)     // .keyboardType(.numberPad)
                .frame(width: AppTheme.Sizing.inputMedium)
                .multilineTextAlignment(.center)
                .font(AppTheme.Typography.heroPrice)
                .editableFieldStyle()
            Button("+") { batchSize += 1 }
        }
        // Quick-select chips row for common batch sizes
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach([5, 10, 25, 50], id: \.self) { size in
                Button("\(size)") { batchSize = size }
                    .buttonStyle(.bordered)
                    .tint(batchSize == size ? AppTheme.Colors.accent : .secondary)
            }
        }
    }
}
.backgroundStyle(AppTheme.Colors.pricingSurface)
```

**Sync:** `batchSizeText` ↔ `batchSize` via `onChange` modifiers. Clamp minimum to 1. Same clear-on-focus / restore-on-blur pattern used in `PricingCalculatorView`.

### Section 2: Labor Time Forecast (icon: `clock`)

```
GroupBox {
    CalculatorSectionHeader(title: "Labor Time", icon: "clock")

    ForEach(sortedWorkStepLinks) { link in
        // Step row
        HStack {
            Text(link.workStep?.title ?? "—")       // .bodyText, left
            Spacer()
            VStack(alignment: .trailing) {
                Text(perProductHoursFormatted)       // note style, secondary
                Text(batchHoursFormatted)            // bodyText, accent
            }
        }
        .sectionGroupStyle()
    }

    // Total hero
    VStack(spacing: AppTheme.Spacing.xs) {
        DetailRow(label: "Total Labor", value: formatHours(totalBatchHours))
        Text(formatHoursReadable(totalBatchHours))
            .font(AppTheme.Typography.heroPrice)
            .foregroundStyle(AppTheme.Colors.accent)
    }
    .heroCardStyle()
}
.backgroundStyle(AppTheme.Colors.pricingSurface)
```

**Labels:** Per-product hours shown in note style as context (e.g., "0.38 hrs/ea"), batch total in accent as the primary value. Step rows sorted by `link.sortOrder`.

### Section 3: Material Shopping List (icon: `cart`)

```
GroupBox {
    CalculatorSectionHeader(title: "Shopping List", icon: "cart")

    ForEach(sortedMaterialLinks) { link in
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            // Primary row
            HStack {
                Text(link.material?.title ?? "—")           // bodyText
                Spacer()
                Text(unitsNeededFormatted + " " + unitName) // bodyText, accent
            }

            // Purchase recommendation sub-row
            HStack {
                Text("Buy \(purchases) × \(bulkQty) \(unitName)")
                    .font(AppTheme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(purchaseCostFormatted)
                    .font(AppTheme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
            }

            // Leftover indicator (only if leftover > 0)
            if leftover > 0 {
                Text("\(leftoverFormatted) \(unitName) leftover")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
        }
        .sectionGroupStyle()
    }

    // Summary hero
    VStack(spacing: AppTheme.Spacing.xs) {
        DetailRow(label: "Material Cost (batch)", value: batchMaterialCostFormatted)
        DetailRow(label: "Total Purchase Cost", value: totalPurchaseCostFormatted)
    }
    .heroCardStyle()
}
.backgroundStyle(AppTheme.Colors.pricingSurface)
```

**Labels:** "Shopping List" is more actionable than "Material Forecast." Primary value is units needed (e.g., "30 oz"). Purchase recommendation is the key insight ("Buy 1 × 32 oz"). "Material Cost (batch)" is what goes into production cost; "Total Purchase Cost" is what you'll actually spend at the store (higher due to rounding up to full bulk units).

### Section 4: Batch Cost Summary (icon: `dollarsign.circle`)

```
GroupBox {
    CalculatorSectionHeader(title: "Batch Cost", icon: "dollarsign.circle")

    DetailRow(label: "Labor", value: laborCostBuffered, note: bufferNote)
    DetailRow(label: "Materials", value: materialCostBuffered, note: bufferNote)
    DetailRow(label: "Shipping", value: shippingCost)
    Divider()

    // Hero: Total + Per Unit
    VStack(spacing: AppTheme.Spacing.xs) {
        HStack {
            Text("Total Batch Cost")
                .font(AppTheme.Typography.sectionHeader)
            Spacer()
            Text(totalBatchCostFormatted)
                .font(AppTheme.Typography.heroPrice)
                .foregroundStyle(AppTheme.Colors.accent)
        }
        HStack {
            Text("Cost Per Unit")
                .font(AppTheme.Typography.bodyText)
                .foregroundStyle(.secondary)
            Spacer()
            Text(costPerUnitFormatted)
                .font(AppTheme.Typography.sectionHeader)
                .foregroundStyle(.secondary)
        }
    }
    .heroCardStyle()
}
.backgroundStyle(AppTheme.Colors.pricingSurface)
```

**Always visible.** Shows $0 rows when product has no data — this is informative, not an error. Buffer percentages shown in note text (e.g., "+10% buffer").

### Section 5: Revenue Forecast (icon: `chart.bar`)

Only shown when at least one `ProductPricing` has `actualPrice > 0`. Uses the **first** pricing with `actualPrice > 0` (most users set up one platform).

```
GroupBox {
    CalculatorSectionHeader(title: "Revenue Forecast", icon: "chart.bar")

    // Per-platform rows (only platforms with actual prices set)
    ForEach(pricingsWithActualPrice) { pricing in
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(pricing.platformType.rawValue)
                .font(AppTheme.Typography.sectionLabel)
            DetailRow(label: "Revenue", value: batchRevenue)
            DetailRow(label: "Total Fees", value: batchFees)
            DetailRow(label: "Production Cost", value: batchProductionCost)
        }
        .sectionGroupStyle()

        // Hero
        VStack(spacing: AppTheme.Spacing.xs) {
            HStack {
                Text("Batch Profit")
                    .font(AppTheme.Typography.sectionHeader)
                Spacer()
                Text(batchProfitFormatted)
                    .font(AppTheme.Typography.heroPrice)
                    .foregroundStyle(batchProfit >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive)
            }
            // Take-home (profit + labor) when labor exists
            if totalLaborCostBuffered > 0 {
                HStack {
                    Text("Batch Take-Home")
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(batchTakeHomeFormatted)
                        .font(AppTheme.Typography.sectionHeader)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .heroCardStyle()
    }
}
.backgroundStyle(AppTheme.Colors.pricingSurface)
```

**Conditional hint when no pricing:** `Text("Set actual prices in the Price tab to see revenue projections.").font(AppTheme.Typography.note).foregroundStyle(.tertiary)`

### Empty State

When product has **no work steps AND no materials** — show a single `ContentUnavailableView`:

```swift
ContentUnavailableView(
    "Nothing to Forecast",
    systemImage: "chart.bar.xaxis.ascending",
    description: Text("Add labor steps and materials in the Build tab to forecast batch production.")
)
```

### Reused Components (no new components needed)

| Component | Source | Used For |
|-----------|--------|----------|
| `CalculatorSectionHeader` | `ViewModifiers.swift` | Section headers with icons |
| `DetailRow` | `ViewModifiers.swift` | Label/value pairs in breakdowns |
| `.heroCardStyle()` | `ViewModifiers.swift` | Hero output values |
| `.sectionGroupStyle()` | `ViewModifiers.swift` | Grouped row backgrounds |
| `.editableFieldStyle()` | `ViewModifiers.swift` | Batch size text field |
| `CurrencyFormatter` | `Engine/CurrencyFormatter.swift` | All monetary values |
| `CostingEngine.formatHours()` | `Engine/CostingEngine.swift` | Decimal hours display |
| `CostingEngine.formatHoursReadable()` | New (Step 1) | "Xh Ym" display |
| `AppTheme.Colors.pricingSurface` | `Theme/AppTheme.swift` | Section backgrounds |

---

## Step 3: Tests (`MakerMarginsTests/Epic5Tests.swift`)

22 tests using Swift Testing (`import Testing`, `@Test`, `#expect`). Same `makeContainer()` pattern as other test files.

### Batch Labor Tests (5)

1. **`batchStepHours_multipliesByBatchSize`** — single step with known hours, batch of 5, verify result = 5×
2. **`batchLaborHours_multipleSteps_sumsAndMultiplies`** — 3 steps, batch of 3, verify sum of all × 3
3. **`batchLaborHours_rawValue_matchesModelOverload`** — raw-value overload matches model overload
4. **`batchLaborHours_zeroRecordedTime_returnsZero`** — step with 0 seconds → 0 hours
5. **`formatHoursReadable_variousInputs`** — 0.5 → "0h 30m", 4.75 → "4h 45m", 0 → "0h 0m", 25.5 → "25h 30m"

### Batch Material Tests (7)

6. **`batchMaterialUnits_multipliesByBatchSize`** — 2 oz/product × 10 = 20 oz
7. **`batchMaterialLineCost_multipliesByBatchSize`** — known cost × batch
8. **`bulkPurchasesNeeded_exactFit`** — 32 needed, 32 per bulk → 1 purchase, 0 leftover
9. **`bulkPurchasesNeeded_partialBulk`** — 30 needed, 32 per bulk → 1 purchase, 2 leftover
10. **`bulkPurchasesNeeded_multipleBulks`** — 65 needed, 32 per bulk → 3 purchases, 31 leftover
11. **`bulkPurchasesNeeded_zeroBulkQuantity`** — guard returns 0 purchases, 0 leftover
12. **`batchPurchaseCost_multipliesPurchasesByBulkCost`** — 3 purchases × $12 = $36

### Batch Cost Tests (3)

13. **`batchProductionCost_multipliesPerUnit`** — known production cost × batch size
14. **`batchCostPerUnit_equalsPerUnitProductionCost`** — total / batch = per-unit (identity)
15. **`batchProductionCost_batchOfOne_equalsSingleUnit`** — batch of 1 matches `totalProductionCost`

### Batch Revenue Tests (4)

16. **`batchRevenue_multipliesByBatchSize`** — ($25 price + $5 shipping) × 10 = $300
17. **`batchTotalFees_includesFixedFeePerTransaction`** — per-sale fees × batch (each sale has its own $0.25)
18. **`batchProfit_multipliesPerSaleProfit`** — known profit × batch
19. **`batchProfit_negativeProfit_scalesCorrectly`** — negative per-unit profit × batch stays negative

### Integration Tests (3)

20. **`fullBatchForecast_woodworkingScenario`** — create product with 4 steps + 4 materials + Etsy pricing matching woodworking template values, batch of 10, verify: total hours, total material cost, production cost, revenue, and profit are all internally consistent
21. **`batchForecast_emptyProduct_allZeros`** — product with no steps/materials, batch of 10, all costs = 0
22. **`batchForecast_noPricing_revenueBatchIsZero`** — product with costs but no pricing, batch revenue = 0

---

## Step 4: Documentation Updates (`CLAUDE.md`)

### Update Epic table

Change Epic 5 row from `Pending` to `**Complete**`.

### Add batch formulas to Calculation Logic section

```
// Batch Forecasting (per batch of N units — Epic 5)
batchStepHours         = laborHoursPerProduct * batchSize
batchLaborHours        = sum of batchStepHours across all steps
batchMaterialUnits     = unitsRequiredPerProduct * batchSize
batchMaterialLineCost  = materialLineCost * batchSize
bulkPurchasesNeeded    = ceil(batchMaterialUnits / bulkQuantity)
batchProductionCost    = totalProductionCost * batchSize
batchCostPerUnit       = batchProductionCost / batchSize
batchRevenue           = (actualPrice + actualShippingCharge) * batchSize
batchTotalFees         = totalSaleFees * batchSize
batchProfit            = actualProfit * batchSize
```

### Add Epic 5 acceptance criteria section

Following the same format as Epics 1–4.5: checkbox list of all features and tests.

### Update directory layout

Add `formatHoursReadable` and batch functions to `CostingEngine.swift` description. Confirm `BatchForecastView.swift` description updated from "STUB (Epic 5)" to "batch forecasting calculator — Epic 5".

---

## Implementation Order

1. `Engine/CostingEngine.swift` — add batch functions (pure math, no dependencies)
2. `MakerMarginsTests/Epic5Tests.swift` — write all 22 tests (verify math is correct)
3. `Views/Products/BatchForecastView.swift` — replace stub with full UI
4. `CLAUDE.md` — update status, formulas, acceptance criteria, directory layout

---

## Verification

1. **CI tests:** Push → GitHub Actions builds and runs all tests (Epic 0–5). All 22 new tests pass alongside existing 83 tests.
2. **Simulator (MacInCloud):** Open a template product (e.g., Woodworking Template) → Forecast tab → verify batch size defaults to 10 → verify labor, shopping list, costs, and revenue sections all populate with correct values.
3. **Shopping list check:** Woodworking, batch of 10 → Hardwood Lumber: need 30 board-feet → "Buy 3 × 10 board-foot" with 0 leftover. Mineral Oil: need 20 oz → "Buy 1 × 32 oz" with 12 oz leftover.
4. **Empty states:** Create a blank product → Forecast tab → verify "Nothing to Forecast" empty state. Add one step → verify labor section appears, materials still hidden.
5. **Revenue conditional:** Product with no pricing → verify revenue section hidden with hint text. Set an actual price on Price tab → return to Forecast → verify revenue section appears.
6. **Edge cases:** Batch of 1 → verify cost per unit matches Build tab's production cost. Batch of 999 → verify no overflow or formatting issues.
