# Epic 6 — Portfolio Metrics & Product Comparison

## Context

A maker with 10+ products needs to answer: "Which of my products are actually worth making?" Today they'd have to tap into each product's Price tab individually and mentally compare numbers. Epic 6 adds a portfolio-level comparison view that ranks all products side-by-side on key financial metrics — earnings, profitability, cost structure — so makers can identify their best earners and spot underperformers at a glance.

The feature is purely computational — no new models, no persistence beyond what already exists. All metrics derive from existing `Product`, `ProductPricing`, and join model data via `CostingEngine`. The user picks a platform (defaulting to General) and a sort metric, and every section updates live.

The "killer feature" is the **Earnings Leaderboard** — horizontal proportional bars that instantly show which products earn the most per sale, normalized with **Effective Hourly Rate** so a $15 keychain and $200 dining table become directly comparable.

---

## Files to Create

| File | Purpose |
|------|---------|
| `MakerMargins/Views/Products/PortfolioView.swift` | Main portfolio comparison view (~350–400 lines) |
| `MakerMarginsTests/Epic6Tests.swift` | Tests for CostingEngine portfolio functions (~250 lines, ~20 tests) |

## Files to Modify

| File | Change |
|------|--------|
| `MakerMargins/Engine/CostingEngine.swift` | Add `// MARK: - Portfolio Metrics (Epic 6)` section with `ProductSnapshot` struct + 4 static functions |
| `MakerMargins/Views/Products/ProductListView.swift` | Add toolbar chart button that pushes `PortfolioView` |
| `CLAUDE.md` | Update Epic 6 status, add portfolio formulas to Calculation Logic, add acceptance criteria |

No model changes. No schema migration. No new design tokens. No changes to `ContentView.swift`, `ProductDetailView.swift`, or `AppTheme.swift`.

---

## Step 1: CostingEngine Portfolio Functions (`Engine/CostingEngine.swift`)

Add a new `// MARK: - Portfolio Metrics (Epic 6)` section at the end of the existing `CostingEngine` enum. All functions follow the established pattern: static, pure, within the caseless enum namespace.

### ProductSnapshot Struct

A value type nested inside `CostingEngine` that captures all portfolio-relevant metrics for a single product. Computed once per product per view refresh to avoid repeated `CostingEngine` calls.

```swift
struct ProductSnapshot {
    let product: Product
    let productionCost: Decimal        // totalProductionCost(product:)
    let laborCostBuffered: Decimal     // totalLaborCostBuffered(product:)
    let materialCostBuffered: Decimal  // totalMaterialCostBuffered(product:)
    let shippingCost: Decimal          // product.shippingCost
    let totalLaborHours: Decimal       // totalLaborHours(product:)
    let earnings: Decimal              // actualProfit + laborCostBuffered (solo-maker hero)
    let profit: Decimal                // actualProfit
    let profitMargin: Decimal?         // actualProfitMargin (nil if no revenue)
    let hourlyRate: Decimal?           // takeHomePerHour (nil if no labor hours)
    let hasPricing: Bool               // whether pricing exists for selected platform
    let platformLabel: String          // e.g. "General", "Etsy"
}
```

### Functions

```swift
/// Returns the ProductPricing record for a specific platform, if it exists
/// and has actualPrice > 0. Returns nil otherwise.
///
/// Portfolio uses this to evaluate all products against the same platform's
/// fee structure, ensuring apples-to-apples comparison.
static func portfolioPricing(
    for product: Product,
    platform: PlatformType
) -> ProductPricing?
// Implementation:
//   product.productPricings
//       .first(where: { $0.platformType == platform && $0.actualPrice > 0 })
```

```swift
/// Builds a full metrics snapshot for one product using the specified platform's pricing.
///
/// When pricing exists: computes profit, earnings, margin, hourly rate using
/// resolvedFees() + actualProfit() + takeHomePerHour() — same math as PricingCalculatorView.
///
/// When no pricing: hasPricing=false, earnings=0, profit=0, margin=nil, hourlyRate=nil.
/// Cost fields (productionCost, laborCostBuffered, etc.) are always populated.
static func productSnapshot(
    product: Product,
    platform: PlatformType
) -> ProductSnapshot
// Implementation:
//   let pricing = portfolioPricing(for: product, platform: platform)
//   let laborBuffered = totalLaborCostBuffered(product: product)
//   let materialBuffered = totalMaterialCostBuffered(product: product)
//   let prodCost = totalProductionCost(product: product)
//   let laborHours = totalLaborHours(product: product)
//
//   if let pricing {
//       let fees = resolvedFees(platformType: platform, user*: pricing.*)
//       let profit = actualProfit(product: product, actualPrice: pricing.actualPrice, ...)
//       let margin = actualProfitMargin(profit: profit, actualPrice: pricing.actualPrice, ...)
//       let earnings = profit + laborBuffered
//       let hourly = takeHomePerHour(actualProfit: profit, laborCostBuffered: laborBuffered, totalLaborHours: laborHours)
//       return ProductSnapshot(hasPricing: true, earnings: earnings, profit: profit, ...)
//   } else {
//       return ProductSnapshot(hasPricing: false, earnings: 0, profit: 0, margin: nil, hourlyRate: nil, ...)
//   }
```

```swift
/// Builds snapshots for all products using the specified platform's pricing.
/// Returns the array unsorted — the view layer handles sort order.
static func portfolioSnapshots(
    products: [Product],
    platform: PlatformType
) -> [ProductSnapshot]
// Implementation: products.map { productSnapshot(product: $0, platform: platform) }
```

```swift
/// Portfolio-level averages computed only across products that have pricing.
///
/// Returns avgProfitMargin=nil when no priced products have revenue.
/// Returns avgHourlyRate=nil when no priced products have labor hours.
static func portfolioAverages(
    snapshots: [ProductSnapshot]
) -> (avgEarnings: Decimal, avgProfitMargin: Decimal?,
      avgHourlyRate: Decimal?, pricedCount: Int, totalCount: Int)
// Implementation:
//   let priced = snapshots.filter { $0.hasPricing }
//   guard !priced.isEmpty else { return (0, nil, nil, 0, snapshots.count) }
//   let avgEarnings = priced.reduce(0) { $0 + $1.earnings } / Decimal(priced.count)
//   let marginsNonNil = priced.compactMap { $0.profitMargin }
//   let avgMargin = marginsNonNil.isEmpty ? nil : marginsNonNil.reduce(0, +) / Decimal(marginsNonNil.count)
//   let ratesNonNil = priced.compactMap { $0.hourlyRate }
//   let avgRate = ratesNonNil.isEmpty ? nil : ratesNonNil.reduce(0, +) / Decimal(ratesNonNil.count)
//   return (avgEarnings, avgMargin, avgRate, priced.count, snapshots.count)
```

---

## Step 2: PortfolioView (`Views/Products/PortfolioView.swift`)

New file. Reuses existing UI components from `ViewModifiers.swift` and follows the same GroupBox + section layout as `PricingCalculatorView` and `BatchForecastView`.

### State

```swift
struct PortfolioView: View {
    @Query(sort: \Product.title) private var products: [Product]
    @Environment(\.currencyFormatter) private var formatter

    @State private var selectedPlatform: PlatformType = .general
    @State private var sortMetric: SortMetric = .earnings

    enum SortMetric: String, CaseIterable {
        case earnings = "Earnings"
        case profitMargin = "Margin"
        case hourlyRate = "Hourly Rate"
        case productionCost = "Cost"
    }
}
```

Platform and sort are **session state only** — not persisted. Default: General platform, sorted by Earnings.

### Body Layout (top to bottom)

```
ScrollView
└── VStack(spacing: AppTheme.Spacing.lg)
    ├── platformPicker               // segmented: General | Etsy | Shopify | Amazon
    ├── portfolioSummaryCard         // hero card: averages + top earner + needs attention
    ├── sortPicker                   // segmented: Earnings | Margin | Hourly Rate | Cost
    ├── earningsLeaderboard          // Section A — hidden if no priced products
    ├── profitabilitySection         // Section B — hidden if no priced products
    ├── costBreakdownSection         // Section C — always visible (costs are platform-independent)
    └── emptyStateHint               // only when zero products exist
```

### Platform Picker

```
Picker("Platform", selection: $selectedPlatform) {
    ForEach(PlatformType.allCases, id: \.self) { platform in
        Text(platform.rawValue).tag(platform)
    }
}
.pickerStyle(.segmented)
.padding(.horizontal)
```

Changing the platform recomputes all snapshots. The Cost Breakdown section is unaffected (costs are platform-independent).

### Portfolio Summary Card (Hero — Top of View)

```
GroupBox {
    CalculatorSectionHeader(title: "Portfolio Overview", icon: "chart.pie")

    VStack(spacing: AppTheme.Spacing.sm) {
        // Priced count
        DetailRow(label: "Products Priced", value: "\(pricedCount) of \(totalCount)")

        // Avg Earnings hero
        HStack {
            Text("Avg. Earnings / Sale")
                .font(AppTheme.Typography.bodyText)
            Spacer()
            Text(formatter.format(avgEarnings))
                .font(AppTheme.Typography.heroPrice)
                .foregroundStyle(avgEarnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive)
        }

        // Avg Margin + Avg Hourly Rate
        if let margin = avgMargin {
            DetailRow(label: "Avg. Profit Margin", value: PercentageFormat.toDisplay(margin) + "%")
        }
        if let rate = avgRate {
            DetailRow(label: "Avg. Hourly Rate", value: formatter.format(rate) + "/hr")
        }

        Divider()

        // Top Earner callout
        if let top = topEarner {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(AppTheme.Colors.accent)
                    .font(.caption)
                Text("Top Earner: \(top.product.title)")
                    .font(AppTheme.Typography.bodyText)
                Spacer()
                Text(formatter.format(top.earnings))
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }

        // Needs Attention callout (only if negative earnings exist)
        if let worst = worstEarner, worst.earnings < 0 {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.Colors.destructive)
                    .font(.caption)
                Text("Needs Attention: \(worst.product.title)")
                    .font(AppTheme.Typography.bodyText)
                Spacer()
                Text(formatter.format(worst.earnings))
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(AppTheme.Colors.destructive)
            }
        }
    }
}
.heroCardStyle()
```

### Sort Picker

```
Picker("Sort by", selection: $sortMetric) {
    ForEach(SortMetric.allCases, id: \.self) { metric in
        Text(metric.rawValue).tag(metric)
    }
}
.pickerStyle(.segmented)
.padding(.horizontal)
```

### Section A: Earnings Leaderboard (icon: `trophy`)

Only shown when at least one product has pricing for the selected platform. Products without pricing listed at bottom with "No [Platform] price set" tertiary label and no bar.

```
GroupBox {
    CalculatorSectionHeader(title: "Earnings / Sale", icon: "trophy")

    ForEach(sortedPricedSnapshots) { snapshot in
        NavigationLink(value: snapshot.product) {
            PortfolioBarRow(
                imageData: snapshot.product.image,
                title: snapshot.product.title,
                value: formatter.format(snapshot.earnings),
                proportion: proportion(snapshot.earnings, max: maxEarnings),
                barColor: snapshot.earnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive,
                valueColor: snapshot.earnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive
            )
        }
        .buttonStyle(.plain)
    }

    // Unpriced products at bottom
    ForEach(unpricedSnapshots) { snapshot in
        NavigationLink(value: snapshot.product) {
            HStack(spacing: AppTheme.Spacing.md) {
                ProductThumbnailView(imageData: snapshot.product.image, size: 32)
                Text(snapshot.product.title)
                    .font(AppTheme.Typography.bodyText)
                Spacer()
                Text("No \(selectedPlatform.rawValue) price")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}
.backgroundStyle(AppTheme.Colors.pricingSurface)
```

### PortfolioBarRow (Private Subview)

Reusable row showing product thumbnail, title, formatted value, and a proportional horizontal bar. The bar width is calculated as `proportion` (0–1) of the available space using `GeometryReader`.

```swift
private struct PortfolioBarRow: View {
    let imageData: Data?
    let title: String
    let value: String
    let proportion: CGFloat      // 0.0–1.0 relative to max in section
    let barColor: Color
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.md) {
                ProductThumbnailView(imageData: imageData, size: 32)
                Text(title)
                    .font(AppTheme.Typography.bodyText)
                    .lineLimit(1)
                Spacer()
                Text(value)
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(valueColor)
            }

            // Proportional bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(barColor.opacity(0.3))
                    .frame(width: max(geo.size.width * proportion, 2), height: 6)
            }
            .frame(height: 6)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}
```

**Proportion helper** (private on `PortfolioView`):

```swift
private func proportion(_ value: Decimal, max: Decimal) -> CGFloat {
    guard max > 0 else { return 0 }
    return CGFloat(NSDecimalNumber(decimal: value / max).doubleValue).clamped(to: 0...1)
}
```

### Section B: Profitability Rankings (icon: `percent`)

Only shown when at least one product has pricing. Two sub-sections separated by a divider.

```
GroupBox {
    CalculatorSectionHeader(title: "Profitability", icon: "percent")

    // Sub-section: Profit Margin %
    Text("Profit Margin")
        .font(AppTheme.Typography.sectionLabel)
        .foregroundStyle(.secondary)

    ForEach(pricedSnapshotsWithMargin) { snapshot in
        NavigationLink(value: snapshot.product) {
            PortfolioBarRow(
                title: snapshot.product.title,
                value: PercentageFormat.toDisplay(snapshot.profitMargin!) + "%",
                proportion: proportion(snapshot.profitMargin!, max: maxMargin),
                barColor: AppTheme.Colors.accent,
                valueColor: snapshot.profitMargin! >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive
            )
        }
        .buttonStyle(.plain)
    }

    Divider()

    // Sub-section: Effective Hourly Rate
    Text("Effective Hourly Rate")
        .font(AppTheme.Typography.sectionLabel)
        .foregroundStyle(.secondary)

    ForEach(pricedSnapshotsWithHourlyRate) { snapshot in
        NavigationLink(value: snapshot.product) {
            PortfolioBarRow(
                title: snapshot.product.title,
                value: formatter.format(snapshot.hourlyRate!) + "/hr",
                proportion: proportion(snapshot.hourlyRate!, max: maxHourlyRate),
                barColor: AppTheme.Colors.accent,
                valueColor: snapshot.hourlyRate! >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive
            )
        }
        .buttonStyle(.plain)
    }

    // Products with no labor hours
    ForEach(pricedSnapshotsNoHours) { snapshot in
        HStack {
            Text(snapshot.product.title)
                .font(AppTheme.Typography.bodyText)
            Spacer()
            Text("N/A")
                .font(AppTheme.Typography.note)
                .foregroundStyle(.tertiary)
        }
    }
}
.backgroundStyle(AppTheme.Colors.pricingSurface)
```

### Section C: Cost Breakdown (icon: `chart.bar`)

**Always visible** — costs are computable regardless of platform selection. Each product gets a horizontal stacked bar showing the proportion of labor (amber), material (sage green), and shipping (gray) within its total production cost. Total cost value right-aligned.

```
GroupBox {
    CalculatorSectionHeader(title: "Cost Breakdown", icon: "chart.bar")

    ForEach(sortedSnapshots) { snapshot in
        NavigationLink(value: snapshot.product) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                HStack(spacing: AppTheme.Spacing.md) {
                    ProductThumbnailView(imageData: snapshot.product.image, size: 32)
                    Text(snapshot.product.title)
                        .font(AppTheme.Typography.bodyText)
                        .lineLimit(1)
                    Spacer()
                    Text(formatter.format(snapshot.productionCost))
                        .font(AppTheme.Typography.sectionHeader)
                        .foregroundStyle(.secondary)
                }

                // Stacked bar: labor | material | shipping
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        let total = snapshot.productionCost
                        let lFrac = total > 0 ? CGFloat(truncating: (snapshot.laborCostBuffered / total) as NSDecimalNumber) : 0
                        let mFrac = total > 0 ? CGFloat(truncating: (snapshot.materialCostBuffered / total) as NSDecimalNumber) : 0
                        // shipping gets remainder

                        Rectangle()
                            .fill(AppTheme.Colors.accent.opacity(0.5))
                            .frame(width: geo.size.width * lFrac)
                        Rectangle()
                            .fill(AppTheme.Colors.categoryBadge.opacity(0.5))
                            .frame(width: geo.size.width * mFrac)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }
                .frame(height: 8)
            }
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .buttonStyle(.plain)
    }

    // Legend
    HStack(spacing: AppTheme.Spacing.lg) {
        legendDot(color: AppTheme.Colors.accent.opacity(0.5), label: "Labor")
        legendDot(color: AppTheme.Colors.categoryBadge.opacity(0.5), label: "Materials")
        legendDot(color: Color.secondary.opacity(0.3), label: "Shipping")
    }
    .font(AppTheme.Typography.note)
    .foregroundStyle(.tertiary)
    .padding(.top, AppTheme.Spacing.xs)
}
.backgroundStyle(AppTheme.Colors.pricingSurface)
```

### Empty States

**No products at all:**
```swift
ContentUnavailableView(
    "No Products Yet",
    systemImage: "chart.bar.xaxis.ascending",
    description: Text("Create products and set prices to compare your portfolio.")
)
```

**Products exist but none have pricing for selected platform** (shown in place of Sections A & B):
```swift
ContentUnavailableView(
    "No \(selectedPlatform.rawValue) Prices Set",
    systemImage: "tag",
    description: Text("Set actual prices on the \(selectedPlatform.rawValue) tab in each product's Price section to see earnings and profitability.")
)
```

### Sorting Logic

A computed property `sortedSnapshots` that re-sorts based on `sortMetric`:

```swift
private var sortedSnapshots: [CostingEngine.ProductSnapshot] {
    let all = CostingEngine.portfolioSnapshots(products: products, platform: selectedPlatform)
    switch sortMetric {
    case .earnings:
        return all.sorted { $0.earnings > $1.earnings }
    case .profitMargin:
        return all.sorted {
            ($0.profitMargin ?? Decimal(-999)) > ($1.profitMargin ?? Decimal(-999))
        }
    case .hourlyRate:
        return all.sorted {
            ($0.hourlyRate ?? Decimal(-999)) > ($1.hourlyRate ?? Decimal(-999))
        }
    case .productionCost:
        return all.sorted { $0.productionCost > $1.productionCost }
    }
}
```

Priced/unpriced splits derived from `sortedSnapshots`:
```swift
private var pricedSnapshots: [CostingEngine.ProductSnapshot] {
    sortedSnapshots.filter { $0.hasPricing }
}
private var unpricedSnapshots: [CostingEngine.ProductSnapshot] {
    sortedSnapshots.filter { !$0.hasPricing }
}
```

### Reused Components (no new components needed)

| Component | Source | Used For |
|-----------|--------|----------|
| `CalculatorSectionHeader` | `ViewModifiers.swift` | Section headers with icons |
| `DetailRow` | `ViewModifiers.swift` | Label/value pairs in summary card |
| `.heroCardStyle()` | `ViewModifiers.swift` | Summary card background |
| `ProductThumbnailView` | `ProductListView.swift` | Product thumbnails in bar rows |
| `PercentageFormat` | `ViewModifiers.swift` | Formatting margin percentages |
| `CurrencyFormatter` | `Engine/CurrencyFormatter.swift` | All monetary values |
| `AppTheme.Colors.pricingSurface` | `Theme/AppTheme.swift` | Section backgrounds |
| `AppTheme.Colors.accent` | `Theme/AppTheme.swift` | Positive values, labor bars |
| `AppTheme.Colors.categoryBadge` | `Theme/AppTheme.swift` | Material bars |
| `AppTheme.Colors.destructive` | `Theme/AppTheme.swift` | Negative values |

---

## Step 3: ProductListView Integration (`Views/Products/ProductListView.swift`)

### Toolbar Button

Add a `NavigationLink` in the `topBarLeading` toolbar alongside the existing list/grid toggle button:

```swift
ToolbarItem(placement: .topBarLeading) {
    HStack(spacing: 0) {
        // Existing grid toggle
        Button {
            isGridMode.toggle()
        } label: {
            Image(systemName: isGridMode ? "list.bullet" : "square.grid.2x2")
        }

        // Portfolio button
        NavigationLink {
            PortfolioView()
        } label: {
            Image(systemName: "chart.bar.xaxis.ascending")
        }
    }
}
```

No additional `navigationDestination` registration needed — `PortfolioView` uses `NavigationLink(value: snapshot.product)` which is caught by the existing `navigationDestination(for: Product.self)` in `ProductListView`.

**Important:** `ProductThumbnailView` is currently a `private struct` inside `ProductListView.swift`. It needs to be made `internal` (remove the `private` access modifier) so `PortfolioView` can use it. Alternatively, move it to `ViewModifiers.swift` alongside `WorkStepThumbnailView` and `MaterialThumbnailView`.

---

## Step 4: Tests (`MakerMarginsTests/Epic6Tests.swift`)

20 tests using Swift Testing (`import Testing`, `@Test`, `#expect`). Same `makeContainer()` helper pattern as other test files — in-memory `ModelContainer` with all 8 model types.

### portfolioPricing Tests (5)

1. **`portfolioPricing_noRecords_returnsNil`** — product with no ProductPricing → nil for any platform
2. **`portfolioPricing_generalWithPrice_returnsGeneral`** — General pricing with actualPrice > 0, query .general → returns it
3. **`portfolioPricing_generalWithPrice_queryEtsy_returnsNil`** — General pricing exists but query .etsy → nil (no Etsy record)
4. **`portfolioPricing_etsyWithPrice_queryEtsy_returnsIt`** — Etsy pricing with actualPrice > 0, query .etsy → returns it
5. **`portfolioPricing_generalZeroPrice_returnsNil`** — General pricing with actualPrice = 0, query .general → nil

### productSnapshot Tests (5)

6. **`productSnapshot_fullProduct_allFieldsPopulated`** — product with steps, materials, and General pricing: verify productionCost, laborCostBuffered, materialCostBuffered, earnings = profit + laborBuffered, hasPricing = true
7. **`productSnapshot_noPricing_defaultsToZero`** — product with costs but no pricing: hasPricing = false, earnings = 0, profit = 0, profitMargin = nil, hourlyRate = nil; cost fields still populated
8. **`productSnapshot_noLaborSteps_hourlyRateNil`** — product with materials + pricing but no steps: hourlyRate = nil, laborCostBuffered = 0, earnings still computed (profit + 0)
9. **`productSnapshot_noMaterials_materialCostZero`** — product with steps + pricing but no materials: materialCostBuffered = 0, all other metrics normal
10. **`productSnapshot_emptyProduct_allZeros`** — product with nothing: all cost fields = 0, hasPricing = false

### portfolioAverages Tests (5)

11. **`portfolioAverages_mixedPricedAndUnpriced_averagesOnlyPriced`** — 3 products, 2 priced: averages computed from 2, pricedCount = 2, totalCount = 3
12. **`portfolioAverages_allPriced_pricedCountEqualsTotalCount`** — all products priced: pricedCount = totalCount
13. **`portfolioAverages_nonePriced_safeDefaults`** — no products priced: avgEarnings = 0, avgMargin = nil, avgRate = nil, pricedCount = 0
14. **`portfolioAverages_singleProduct_equalsOwnValues`** — one priced product: averages = that product's values
15. **`portfolioAverages_negativeProfitIncluded`** — product with negative profit: included in averages (not filtered out)

### Cross-Verification Tests (5)

16. **`snapshot_earnings_matchesDirectCalculation`** — snapshot.earnings = `CostingEngine.actualProfit(...) + CostingEngine.totalLaborCostBuffered(product:)` for same inputs
17. **`snapshot_profitMargin_matchesDirectCalculation`** — snapshot.profitMargin = `CostingEngine.actualProfitMargin(...)` for same inputs
18. **`snapshots_sortedByEarnings_correctOrder`** — 3 products with known earnings → sorted descending
19. **`snapshots_sortedByProductionCost_correctOrder`** — 3 products with known costs → sorted descending
20. **`snapshots_differentCategories_includesAll`** — products across different categories all appear in snapshots

---

## Step 5: Documentation Updates (`CLAUDE.md`)

### Update Epic table

Change Epic 6 row from `Pending` to `**Complete**`.

### Add portfolio formulas to Calculation Logic section

```
// Portfolio Metrics (per product, platform-specific — Epic 6)
portfolioPricing       = product.productPricings.first(where: platform & actualPrice > 0)
productSnapshot        = { productionCost, laborCostBuffered, materialCostBuffered, shippingCost,
                           totalLaborHours, earnings, profit, profitMargin, hourlyRate, hasPricing }
earnings               = actualProfit + laborCostBuffered     // same as "Your Earnings" in Price tab
portfolioAverages      = avg(earnings), avg(profitMargin), avg(hourlyRate) across priced products
```

### Add Epic 6 acceptance criteria section

Following the same format as Epics 1–5: checkbox list of all features and tests.

### Update directory layout

Add `PortfolioView.swift` under `Views/Products/` and `Epic6Tests.swift` under `MakerMarginsTests/`.

### Update navigation structure

Add portfolio navigation path under ProductListView:
```
ProductListView                            [ROOT — chart icon pushes PortfolioView]
├── [push] PortfolioView                   [Level 1 — platform picker, sort, rankings]
│   └── [push] ProductDetailView           [Level 2 ��� tapping a product in rankings]
```

---

## Implementation Order

1. `Engine/CostingEngine.swift` — add `ProductSnapshot` struct + 4 portfolio functions (pure math, no dependencies)
2. `MakerMarginsTests/Epic6Tests.swift` — write all 20 tests (verify math is correct before building UI)
3. `Views/Products/PortfolioView.swift` — build full portfolio view with all 4 sections
4. `Views/Products/ProductListView.swift` — add toolbar button + make `ProductThumbnailView` accessible
5. `CLAUDE.md` — update status, formulas, acceptance criteria, directory layout

---

## Verification

1. **CI tests:** Push → GitHub Actions builds and runs all tests (Epic 0–6). All 20 new tests pass alongside existing ~105 tests.
2. **Simulator (MacInCloud):** Apply all 5 templates → open Portfolio view → verify all 5 products appear with bars and rankings.
3. **Platform picker:** Switch from General to Etsy → verify products re-sort based on Etsy pricing. Products without Etsy pricing show "No Etsy price" label.
4. **Sort picker:** Switch between Earnings, Margin, Hourly Rate, Cost → verify sections re-sort correctly.
5. **Cost Breakdown:** Verify stacked bars show correct proportions — woodworking template should be labor-heavy, candle template should be material-heavy.
6. **Product navigation:** Tap a product in any section → verify it pushes to ProductDetailView within the same NavigationStack.
7. **Summary card:** Verify "Top Earner" and "Needs Attention" callouts are correct. Change a product's price to create a negative-earnings product → verify "Needs Attention" appears.
8. **Empty states:** Delete all products → verify "No Products Yet" empty state. Create a product with no pricing → verify earnings/profitability hidden with hint, cost breakdown still visible.
9. **Edge cases:** Product with zero costs → verify zero-width bars (no crashes). All products with same earnings → verify equal-width bars. Single product → verify it gets full-width bar.
