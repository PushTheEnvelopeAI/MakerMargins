# Production Readiness Refactor Plan

**Goal:** Raise scores from Code Quality **33/55** and UI/UX **38/60** to ship-ready levels
**Baseline:** Audit date 2026-04-04, rubrics in `plans/rubric-code-quality.md` and `plans/rubric-ui-ux.md`
**Approach:** 6 phases in strict dependency order. Each phase is independently committable and produces a testable result.

---

## Phase 1 — Crash Prevention & Data Safety

**What:** Fix every code path that can crash the app or silently destroy user data.
**Why first:** These are ship-blockers. A fatalError on launch and force unwraps in list views mean the app can crash during normal use. Forms losing data on swipe-dismiss is the #1 user frustration.
**Effort:** Small — targeted fixes, no structural changes.

### 1.1 Replace fatalError in app startup

**File:** `MakerMarginsApp.swift:40`

Wrap the second `try ModelContainer(...)` in a `do/catch`. On failure, fall back to an in-memory container and surface a recovery alert via an environment flag. The user sees "Your data could not be loaded" instead of a permanent crash.

### 1.2 Remove 4 force unwraps in list views

**Files:** `WorkStepListView.swift:186,216` and `MaterialListView.swift:185,215`

Replace `link.workStep!` / `link.material!` with `guard let` + `EmptyView()` return in the `stepRow()`, `materialRow()`, and `reorderRow()` functions. No nil check exists in these individual functions despite one existing in the outer ForEach.

### 1.3 Fix 2 dark mode color violations

**Files:** `StopwatchView.swift:131`, `ProductListView.swift:259`

Replace `.foregroundStyle(.white)` with adaptive colors. StopwatchView: use `.primary` or verify the button background guarantees contrast. ProductListView: verify accent chip background in both modes; if contrast holds, document it — if not, use an adaptive foreground.

### 1.4 Protect all form sheets from accidental dismiss

**Files:** `ProductFormView`, `WorkStepFormView`, `MaterialFormView`

Add `.interactiveDismissDisabled(hasUnsavedChanges)` to each. Compute `hasUnsavedChanges` by comparing current field values against initial values (empty for create, original values for edit). Store originals in `onAppear`.

### 1.5 Add keyboard dismiss toolbar to all forms

**Files:** `ProductFormView`, `WorkStepFormView`, `MaterialFormView`, `PricingCalculatorView`, `PlatformPricingDefaultFormView`, `SettingsView`

Add `.toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil } } }` to each view that uses a `@FocusState`.

### 1.6 Fix title validation (whitespace + feedback)

**Files:** `ProductFormView`, `WorkStepFormView`, `MaterialFormView`

Change validation from `title.isEmpty` to `title.trimmingCharacters(in: .whitespaces).isEmpty`. Add an inline "Title is required" hint in `.caption` secondary text below the title field, visible only after the field has been focused at least once and is still empty.

### 1.7 Add category deletion confirmation

**File:** `ProductFormView` (inline category swipe)

Add `.confirmationDialog`: "Remove this category? Products in this category will become uncategorized but won't be deleted."

### Phase 1 Verification

- [ ] App launches when store file is corrupted — shows alert, no crash
- [ ] WorkStepListView and MaterialListView render without crashes
- [ ] StopwatchView buttons visible in both light and dark mode
- [ ] Category chip text readable in both modes
- [ ] Swiping down on a form with unsaved data blocks dismiss
- [ ] Keyboard "Done" button appears above all numeric keyboards
- [ ] Whitespace-only titles rejected; inline hint visible
- [ ] Category deletion shows confirmation dialog
- [ ] All existing tests pass

---

## Phase 2 — Accessibility

**What:** Make the app usable with VoiceOver, Dynamic Type, and assistive technologies.
**Why second:** Largest combined point gain (+2 code quality, +2 UI/UX). Highest App Store rejection risk. Apple's review team actively tests VoiceOver.
**Effort:** Medium — touches ~20 files but each change is a single modifier addition.

### 2.1 Accessibility labels on all interactive elements

Add `accessibilityLabel` to every custom button and icon:

| Component | Label |
|-----------|-------|
| Reorder up/down arrows | "Move [name] up" / "Move [name] down" |
| Batch +/- buttons | "Increase batch size" / "Decrease batch size" |
| Batch preset chips | "Set batch size to [N]" |
| Add menu (+) buttons | "Add work step" / "Add material" |
| Edit pencil toolbar | "Edit [name]" |
| Delete/more menu | "More options" |
| List/grid toggle | "Switch to [grid/list] view" |
| Category filter chips | "[Category] filter" |
| Template cards | "[Name]: [summary]" |
| Portfolio card | "Compare your [N] products" |

### 2.2 Accessibility labels on hero values and data displays

Add contextual `accessibilityLabel` to all computed value displays:

| Component | Label |
|-----------|-------|
| Target Price hero | "Target Price: [value]" |
| Earnings hero | "Your Earnings per Sale: [value]" |
| Hourly rate | "Your Hourly Pay: [value]" |
| Batch Earnings hero | "Batch Earnings: [value]" |
| Total Labor hero | "Total Labor Time: [value] hours" |
| Production Cost total | "Total Production Cost: [value]" |
| Portfolio avg earnings | "Average Earnings per Sale: [value]" |
| Portfolio bar rows | "[Product]: [value], rank [N] of [total]" |
| Stacked cost bars | "Labor [X]%, Materials [Y]%, Shipping [Z]%" |
| Stopwatch timer | `accessibilityValue` updating with running time |

### 2.3 Hide decorative elements from VoiceOver

Add `.accessibilityHidden(true)` to: placeholder thumbnails (3 thumbnail views in ViewModifiers.swift), chevron icons in list rows, portfolio legend color dots. Verify CalculatorSectionHeader icon is already hidden.

### 2.4 Group composite views for VoiceOver

Add `.accessibilityElement(children: .combine)` to: `.heroCardStyle()` modifier in ViewModifiers.swift, cost summary rows in ProductCostSummaryCard, all portfolio bar rows. Verify stacked cost bars have `.ignore` + descriptive label.

### 2.5 Fix touch targets to 44x44pt minimum

Add `.frame(minWidth: 44, minHeight: 44)` to: reorder arrows, batch +/- buttons, plus-circle add buttons. Increase vertical padding on category filter chips.

### 2.6 Dynamic Type and Reduce Motion

Replace `timerDisplay` font from `Font.system(size: 56, weight: .light, design: .monospaced)` to `.largeTitle.monospaced()` or equivalent scalable style in AppTheme.swift.

Add `@Environment(\.accessibilityReduceMotion) var reduceMotion` and guard `withAnimation` calls in WorkStepListView/MaterialListView reorder toggle, and `.contentTransition(.numericText())` in StopwatchView.

### Phase 2 Verification

- [ ] VoiceOver can navigate: Products list → create product → add step → set price → view portfolio
- [ ] Every button announces its purpose (no bare "Button" readings)
- [ ] Hero values announce with context
- [ ] Decorative images are silent
- [ ] Touch targets ≥ 44x44pt (test with Accessibility Inspector)
- [ ] Timer font scales with Dynamic Type
- [ ] Reduce Motion disables reorder and stopwatch animations
- [ ] All existing tests pass

---

## Phase 3 — Architecture & Engine Completeness

**What:** Move all inline calculations from views into CostingEngine. Remove layer violations. Fix the N+1 performance issue. Clean up remaining theme token violations.
**Why third:** After this phase, every calculation is unit-testable. Unblocks Phase 5 (component deduplication needs clean code) and Phase 6 (tests need engine functions to exist).
**Effort:** Medium — ~15 new engine functions, ~50 lines moved from views, theme token replacements.

### 3.1 Move inline calculations from BatchForecastView to CostingEngine

**File:** `BatchForecastView.swift` lines 39, 43, 47, 341, 378, 401, 409

New CostingEngine functions: `batchLaborCostBuffered`, `batchMaterialCostBuffered`, `batchShippingCost`, `batchProductionCostExShipping`, `batchEarnings`, `batchEarningsPerUnit`. Each is `existingFunction(product) * Decimal(batchSize)`. Replace inline arithmetic in view with engine calls.

### 3.2 Move inline calculations from PricingCalculatorView to CostingEngine

**File:** `PricingCalculatorView.swift` lines 286, 477, 486, 499

New functions: `platformFeeAmount`, `processingFeeAmount`, `marketingFeeAmount`, `totalPercentFees`. Replace inline expressions.

### 3.3 Move inline calculations from PortfolioView to CostingEngine

**File:** `PortfolioView.swift` lines 257, 259, 261

New function: `costBreakdownFractions(laborCostBuffered:materialCostBuffered:shippingCost:)` returning `(CGFloat, CGFloat, CGFloat)`. Returns (0,0,0) when total is zero.

### 3.4 Use PercentageFormat for buffer conversion

**Files:** `WorkStepListView.swift:56`, `MaterialListView.swift:56`

Replace `(Decimal(string: bufferText) ?? 0) / 100` with `PercentageFormat.fromDisplay(bufferText)`.

### 3.5 Move display logic out of PlatformFeeProfile model

**File:** `PlatformFeeProfile.swift` lines 108-130

Move 3 computed properties (`platformFeeDisplay`, `paymentProcessingDisplay`, `marketingFeeDisplay`) to a new `Engine/PlatformFeeFormatter.swift` as extension methods on `PlatformType`. Update call sites.

### 3.6 Move StopwatchView timer formatting to Engine

**File:** `StopwatchView.swift` lines 153, 155

Add `CostingEngine.formatStopwatchTime(seconds: TimeInterval) -> String`. Replace inline `String(format:)` calls.

### 3.7 Remove SwiftData import from CostingEngine

**File:** `CostingEngine.swift:12`

Delete `import SwiftData`. Verify compilation.

### 3.8 Fix N+1 in productSnapshot

**File:** `CostingEngine.swift:613-686`

Refactor `productSnapshot()` to traverse `productWorkSteps` once (accumulating both labor cost and hours) and `productMaterials` once (accumulating material cost), then derive all other values from cached locals. Eliminates ~4x redundant relationship traversals per product.

### 3.9 Fix remaining theme token violations

| File | Line | Current | Fix |
|------|------|---------|-----|
| WorkStepDetailView.swift | 310, 315 | `Color.red.opacity(0.1/0.3)` | `AppTheme.Colors.destructive.opacity(...)` |
| MaterialDetailView.swift | 282, 287 | `Color.red.opacity(0.1/0.3)` | `AppTheme.Colors.destructive.opacity(...)` |
| PricingCalculatorView.swift | multiple | literal `.red` | `AppTheme.Colors.destructive` |
| PortfolioView.swift | 284 | `cornerRadius: 3` | New `AppTheme.CornerRadius` value |
| PortfolioView.swift | 286, 320, 467, 469 | magic numbers | New `AppTheme.Sizing` constants |
| TemplatePickerView.swift | 81 | `.font(.system(size: 36))` | Scalable style or new Typography token |
| ViewModifiers.swift | 23 | inline shadow params | New `AppTheme.Shadow` struct |

### 3.10 Fix hardcoded currency symbol

**File:** `PricingCalculatorView.swift:528`

Replace `"Production cost is $0"` with `"Production cost is \(formatter.format(0))"`.

### Phase 3 Verification

- [ ] Zero arithmetic on `Decimal` in any view body (grep to confirm)
- [ ] Zero `String(format:)` in any view file
- [ ] Zero display-formatting computed properties in any model file
- [ ] `CostingEngine.swift` has no `import SwiftData`
- [ ] Zero hardcoded colors, font sizes, spacing, or corner radii in view files
- [ ] Zero-production-cost message respects EUR currency
- [ ] Portfolio renders correctly after N+1 fix
- [ ] All existing tests pass

---

## Phase 4 — Navigation, Feedback, Labeling & Onboarding

**What:** Fix navigation dead ends, add missing action feedback, rename confusing pricing terms, and improve the first-run experience.
**Why fourth:** These are daily-use UX friction points. After architecture is clean, we can safely add new navigation paths and buttons without layering them on top of broken code.
**Effort:** Medium — navigation changes in ~8 views, string replacements across ~12 files.

### 4.1 Make "Used By" products tappable NavigationLinks

**Files:** `WorkStepDetailView`, `MaterialDetailView`

When viewed from library tab (`product == nil`), wrap each product in `NavigationLink(value: linkedProduct)`. Register `.navigationDestination(for: Product.self)` in WorkshopView and MaterialsLibraryView.

### 4.2 Add stopwatch shortcut to WorkStepDetailView toolbar

**File:** `WorkStepDetailView`

Add timer SF Symbol button that presents StopwatchView as `fullScreenCover` directly. Reduces path from 5 taps to 2 taps from Labor tab.

### 4.3 Auto-navigate after creation from library tabs

**Files:** `WorkshopView`, `MaterialsLibraryView`

Add `newlyCreatedStep`/`newlyCreatedMaterial` state + `onDismiss` navigation pattern matching ProductListView's existing implementation.

### 4.4 Product duplication feedback

**File:** `ProductListView`

After `duplicateProduct()`, auto-navigate: `navigationPath.append(copy)`.

### 4.5 Stopwatch dismiss always visible

**File:** `StopwatchView`

Show X button in all states. When tapped while running, show confirmation: "Stop timer and discard?"

### 4.6 "Use Target Price" persists as reset option

**File:** `PricingCalculatorView`

When actual price exists, show "Reset to Target Price" as a secondary text button instead of hiding the affordance entirely.

### 4.7 "Fees too high" guidance

**File:** `PricingCalculatorView`

Change "— (fees too high)" to "— Fees + margin exceed 100%. Try lowering your profit margin or fee percentages."

### 4.8 Pricing terminology renames

| Current | New | Files |
|---------|-----|-------|
| "Margin After Costs" | "Profit (Excl. Labor)" | PricingCalculatorView, BatchForecastView |
| "Effective Hourly Rate" | "Your Hourly Pay" | PricingCalculatorView, BatchForecastView, PortfolioView |
| "Production Costs" | "Cost Breakdown" | PricingCalculatorView |
| "% Sales from Ads" | "% of Sales from Ads" | PricingCalculatorView, PlatformPricingDefaultFormView |
| "Total Labor" | "Total Labor Cost" | WorkStepListView |
| "Total Materials" | "Total Material Cost" | MaterialListView |
| "Payment Processing" | "Transaction Fees" | PricingCalculatorView |

### 4.9 Locked fee platform context

**File:** `PricingCalculatorView`

Change lock icon from `.quaternary` to `.tertiary`. Add "Set by [Platform]" text. Update accessibility label: "[label]: [value], set by [platform], not editable."

### 4.10 Improve empty state actionability

**Files:** `WorkStepListView`, `MaterialListView`

Change "Add work steps to calculate labor costs" → "Tap + above to add labor steps and calculate costs." Same pattern for materials.

### 4.11 Add helper text for non-obvious fields

| Field | Helper text | File |
|-------|------------|------|
| "% of Sales from Ads" | "What fraction of your sales come through paid advertising?" | PricingCalculatorView, PlatformPricingDefaultFormView |
| "Your Hourly Rate" | "Your default labor rate for new work steps." | SettingsView |

### 4.12 Human-readable time in WorkStepDetailView

**File:** `WorkStepDetailView`

Below "Hours per [unit]: 0.75", add secondary line: "(45m)" using `CostingEngine.formatHoursReadable()`.

### 4.13 Template picker improvements

**File:** `TemplatePickerView`

Add content preview: "\(template.workSteps.count) steps, \(template.materials.count) materials, Etsy pricing" in `.caption` below each card.

### 4.14 First-run "aha moment"

**Files:** `ProductListView` (empty state), `ProductDetailView`

When `products.isEmpty`, show prominent "Start from Template" button (`.borderedProminent`) + secondary "Create Blank Product" (`.bordered`) instead of just text.

After template application, auto-switch to Price tab: detect `productPricings.contains(where: { $0.actualPrice > 0 })` on first appear with a one-shot flag.

### Phase 4 Verification

- [ ] Tapping product in "Used By" navigates to product detail
- [ ] Stopwatch reachable in 2 taps from Labor tab
- [ ] New step/material from library auto-navigates to detail
- [ ] Product duplication auto-navigates to copy
- [ ] Stopwatch X visible in all states with running confirmation
- [ ] "Reset to Target Price" appears when price is set
- [ ] All pricing labels updated, no old terms remain
- [ ] Lock icons show "Set by [Platform]" text
- [ ] Empty states say HOW to act, not just what's missing
- [ ] WorkStepDetailView shows "0.75 (45m)" format
- [ ] Template cards show content count
- [ ] Empty product list shows prominent template CTA
- [ ] Template products auto-switch to Price tab

---

## Phase 5 — Component Deduplication & Dead Code

**What:** Extract shared components from the WorkStep/Material parallel hierarchies. Delete dead legacy files. Clean up model integrity.
**Why fifth:** Largest refactor in the plan. Requires clean architecture (Phase 3) so extracted components contain correct, engine-delegated code. Eliminates ~1,200 lines of duplication.
**Effort:** Large — structural refactor touching ~15 files.

### 5.1 Extract BufferInputSection

**From:** `WorkStepListView.swift:256-265`, `MaterialListView.swift:255-265`

Create shared `BufferInputSection(label:helperText:bufferValue:)` in ViewModifiers.swift. Manages text state, focus, and clear-on-focus/restore-on-blur internally.

### 5.2 Replace inline CurrencyInputField violations

**Files:** `MaterialFormView.swift:136-144`, `SettingsView.swift:42-59`

Replace manual HStack + symbol + TextField with existing `CurrencyInputField` component.

### 5.3 Extract shared LibraryContent view

**From:** `WorkshopView.swift` (99 lines), `MaterialsLibraryView.swift` (101 lines) — 92% overlap

Use wrapper pattern: keep WorkshopView and MaterialsLibraryView as thin wrappers owning `@Query`, pass results to a shared `LibraryContent` view that handles the ~70 lines of identical rendering logic (empty state, search filter, list rows).

### 5.4 Extract shared list sub-components

**From:** `WorkStepListView.swift` (~409 lines), `MaterialListView.swift` (~406 lines) — 93% overlap

Extract smaller shared components rather than one monolithic generic:
- `ItemRowView` — thumbnail + title + cost + chevron
- `ReorderRowView` — arrows + thumbnail + title
- `ExistingItemPickerView` — multi-select sheet with checkmarks
- `BufferInputSection` — already done in 5.1

Reduces each list view from ~400 lines to ~150 lines of unique wiring.

### 5.5 Extract shared detail view sections

**From:** `WorkStepDetailView.swift` (~339 lines), `MaterialDetailView.swift` (~311 lines) — 83% overlap

Extract:
- `ItemHeaderView(imageData:summary:)` — image + summary (~40 lines)
- `UsedBySection(linkedProducts:product:)` — linked products list (~30 lines), now with NavigationLink from Phase 4
- `RemoveFromProductButton(product:itemTitle:onRemove:)` — destructive button (~25 lines)

### 5.6 Delete legacy dead code

**Files:** `Views/Categories/CategoryListView.swift` (79 lines), `Views/Categories/CategoryFormView.swift` (59 lines)

Delete both files. Verify no references. Update CLAUDE.md directory layout and notes.

### 5.7 Add ProductPricing unique constraint guard

**File:** `PricingCalculatorView.swift` (creation site)

Add debug assertion before creating a new ProductPricing: `assert(product.productPricings.filter { $0.platformType == platform }.count <= 1)`. The existing `.first(where:)` handles it in release.

### Phase 5 Verification

- [ ] WorkshopView and MaterialsLibraryView use shared LibraryContent
- [ ] WorkStepListView and MaterialListView use shared row, reorder, picker, and buffer components
- [ ] WorkStepDetailView and MaterialDetailView use shared header, UsedBy, and remove components
- [ ] MaterialFormView and SettingsView use CurrencyInputField
- [ ] CategoryListView.swift and CategoryFormView.swift deleted
- [ ] No compilation errors
- [ ] CLAUDE.md updated
- [ ] All existing tests pass

---

## Phase 6 — Test Coverage & Visual Polish

**What:** Fill test gaps for engine functions, formatters, and managers. Apply final visual consistency fixes.
**Why last:** Tests cover new engine functions from Phase 3 and refactored code from Phase 5. Visual polish uses final component structure.
**Effort:** Medium — ~50 new tests + ~10 visual fixes.

### 6.1 Formatter tests

Add tests for `formatDuration()` (zero, 3661s, 86400s), `formatHours()` (zero, precision, trailing zero stripping), and `formatStopwatchTime()` (created in Phase 3).

### 6.2 AppearanceManager tests

Test default setting (.system), UserDefaults persistence, resolvedColorScheme for each setting.

### 6.3 Cross-platform resolvedFees tests

Add `resolvedFees` tests for Shopify and Amazon (currently only Etsy + General).

### 6.4 Cross-platform portfolio tests

Test `portfolioSnapshots` and `portfolioAverages` against Etsy and Shopify fee structures.

### 6.5 Buffered cost isolation tests

Dedicated tests for `totalLaborCostBuffered` and `totalMaterialCostBuffered` with known values and zero buffers.

### 6.6 Negative input value tests

Test `stepLaborCost` with negative laborRate, `materialLineCost` with negative bulkCost, `totalProductionCost` with negative buffer. Document or guard the behavior.

### 6.7 New engine function tests

Happy-path + edge-case tests for all functions created in Phase 3: `batchLaborCostBuffered`, `batchMaterialCostBuffered`, `batchShippingCost`, `batchEarnings`, `batchEarningsPerUnit`, `platformFeeAmount`, `processingFeeAmount`, `marketingFeeAmount`, `costBreakdownFractions`, `totalPercentFees`. Estimated ~15-20 tests.

### 6.8 Unify ProductCostSummaryCard header

Replace plain `GroupBox("Cost Summary")` with `CalculatorSectionHeader(icon: "dollarsign.circle", title: "COST SUMMARY")`.

### 6.9 Use DerivedRow for computed cost subtotals

**File:** `PricingCalculatorView`

Change "Material Cost", "Labor Cost", "Shipping Cost" rows from `DetailRow` to `DerivedRow` (accent color) to signal they're derived from the Build tab.

### 6.10 Unify platform picker style

**File:** `PortfolioView`

Change `.pickerStyle(.menu)` to `.pickerStyle(.segmented)` to match PricingCalculatorView.

### 6.11 Unify toolbar structure

**File:** `ProductDetailView`

Change toolbar from single Menu to pencil button + conditional menu, matching WorkStepDetailView/MaterialDetailView pattern.

### 6.12 Collapsible Target Price Calculator

**File:** `PricingCalculatorView`

Wrap target price section in `DisclosureGroup("Target Price Calculator", isExpanded: $showTargetCalc)`, defaulting to expanded.

### 6.13 Portfolio mini-metrics

**File:** `PortfolioView`

Add secondary caption below product name in each tab showing complementary metrics (e.g., earnings tab shows "Margin: 32% | $18/hr").

### 6.14 Expose duplicate in ProductDetailView

Add "Duplicate Product" to toolbar menu alongside Edit and Delete.

### Phase 6 Verification

- [ ] `formatDuration` and `formatHours` have tests covering zero, normal, large, precision
- [ ] AppearanceManager defaults and persistence tested
- [ ] `resolvedFees` tested for all 4 platforms
- [ ] Portfolio snapshots tested against Etsy and Shopify
- [ ] Buffered costs tested in isolation
- [ ] Negative inputs documented and tested
- [ ] All new Phase 3 engine functions have tests
- [ ] ProductCostSummaryCard header matches CalculatorSectionHeader
- [ ] Derived cost rows use accent color
- [ ] Platform picker is `.segmented` everywhere
- [ ] ProductDetailView toolbar matches other detail views
- [ ] Target Price Calculator is collapsible
- [ ] Portfolio rows show secondary metrics
- [ ] Duplicate available from product detail
- [ ] Full test suite passes: all ~200+ tests green

---

## Summary

| Phase | Focus | Effort | Key Deliverable |
|-------|-------|--------|----------------|
| 1 | Crash Prevention & Data Safety | Small | App can't crash; forms can't lose data |
| 2 | Accessibility | Medium | VoiceOver works; touch targets ≥ 44pt |
| 3 | Architecture & Engine | Medium | All math in CostingEngine; zero layer violations |
| 4 | Navigation, Feedback, Labeling & Onboarding | Medium | No dead ends; clear terminology; first-run "aha" |
| 5 | Component Deduplication & Dead Code | Large | ~1,200 lines eliminated; clean component library |
| 6 | Test Coverage & Visual Polish | Medium | ~50 new tests; unified visual patterns |

### Dependency Chain

```
Phase 1 (Safety)                — no dependencies
    ↓
Phase 2 (Accessibility)         — no hard dependency on 1, but do after to avoid rework
    ↓
Phase 3 (Architecture)          — depends on Phase 1 (force unwrap fixes in list views)
    ↓
Phase 4 (Nav + Labels)          — depends on Phase 3 (engine functions exist for new views)
    ↓
Phase 5 (Components)            — depends on Phase 3 (clean code before extracting generics)
    ↓
Phase 6 (Tests + Polish)        — depends on Phase 3 (test new functions) + Phase 5 (test refactored code)
```

Phases 4 and 5 have no dependency on each other and can run in parallel if desired.

### Projected Scores

| Rubric | Before | After | Rating |
|--------|--------|-------|--------|
| Code Quality | 33/55 | ~46/55 | Ship-ready with minor improvements |
| UI/UX | 38/60 | ~50/60 | Strong UX with minor polish needed |
