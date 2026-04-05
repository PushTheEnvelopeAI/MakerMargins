# MakerMargins — Code Quality Rubric

Production readiness audit for a SwiftUI + SwiftData iOS 26 application.
Each dimension is scored 1–5. A score of 3 means "acceptable for v1 ship." A score of 5 means "exemplary, no meaningful improvements needed."

---

## 1. Architecture & Separation of Concerns

**What to evaluate:** Are data, logic, and presentation cleanly separated? Can each layer be understood, tested, and modified independently?

| Score | Criteria |
|-------|----------|
| 1 | Business logic embedded in views. Models contain UI formatting. No clear layer boundaries. |
| 2 | Some separation exists but leaks are common — views directly compute costs, models have display logic, engine depends on UI state. |
| 3 | Clear 3-layer separation (Models / Engine / Views). Occasional minor leaks (e.g., a view doing a calculation that should be in CostingEngine, or a model with a convenience computed property that belongs in the engine). |
| 4 | Strict separation with no leaks. Models are pure data. CostingEngine owns all math. Views are purely declarative. Managers follow a consistent injection pattern. Edge cases handled in the right layer. |
| 5 | All of 4, plus: layer boundaries are self-documenting (a new developer can identify which layer owns a responsibility without reading CLAUDE.md). Dependency direction is always inward (Views → Engine → Models). No circular references. |

**Specific checks:**
- [x] No arithmetic in SwiftUI view bodies (all math routes through CostingEngine)
- [ ] No `NumberFormatter` / `String(format:)` in views (all formatting routes through CurrencyFormatter or CostingEngine.formatHours)
- [ ] Models contain zero display logic (no computed properties that format strings for UI)
- [ ] CostingEngine has zero SwiftData imports (pure logic, testable without a ModelContainer)
- [x] Managers (CurrencyFormatter, AppearanceManager, LaborRateManager) follow a single consistent pattern
- [x] No view directly reads UserDefaults — all persistence routes through managers

### Audit Result: 3/5

The 3-layer separation (Models / Engine / Views) is clearly established and mostly respected. Managers follow an identical `@Observable` + `EnvironmentKey` + `UserDefaults` pattern. No view touches UserDefaults directly. However, the leaks are systematic, not occasional.

**Violations found:**

- **13+ inline calculations in views.** BatchForecastView.swift has 7 arithmetic operations (batch labor/material/shipping cost, batch production cost, batch earnings, earnings/unit, profit margin). PricingCalculatorView.swift has 4 (total fees, platform fee amount, processing amount, marketing amount). PortfolioView.swift has 3 (cost fraction divisions). WorkStepListView.swift and MaterialListView.swift each do `/ 100` buffer conversions.
- **Display logic in models.** PlatformFeeProfile.swift has 3 computed properties (`platformFeeDisplay`, `paymentProcessingDisplay`, `marketingFeeDisplay`) that format strings for the UI, including `String(format: "%.2f", ...)` directly in the model layer.
- **`String(format:)` in views.** StopwatchView.swift formats the timer display inline instead of routing through a formatter.
- **CostingEngine imports SwiftData.** Unnecessary dependency — the engine receives model objects as parameters but doesn't need the import itself.

---

## 2. Design Token System & Theming

**What to evaluate:** Is there a single source of truth for visual constants? Are tokens comprehensive, consistently applied, and sufficient for dark/light mode?

| Score | Criteria |
|-------|----------|
| 1 | No theme system. Colors, fonts, and spacing are hardcoded throughout views. |
| 2 | Theme file exists but is incomplete — covers colors but not spacing, or has tokens that aren't used. Hardcoded values still appear in views. |
| 3 | Comprehensive token set (colors, spacing, typography, corner radii, sizing). Most views use tokens. A few hardcoded values remain in isolated places. |
| 4 | All visual constants route through AppTheme. Zero hardcoded colors, font sizes, spacing, or corner radii in view files. Dark/light mode handled entirely by token definitions. |
| 5 | All of 4, plus: tokens are semantically named (e.g., `surface`, `surfaceElevated`, `accent` — not `warmCream`, `darkGray`). Token hierarchy is self-documenting. Adding a new theme (e.g., high contrast) would require changes only in AppTheme.swift. |

**Specific checks:**
- [ ] Every `Color(...)` or `UIColor(...)` literal lives in AppTheme.swift, never in view files
- [ ] Every `.font(...)` call uses an AppTheme.Typography value or standard system style, not a hardcoded size
- [ ] Every padding/spacing value uses AppTheme.Spacing, not a magic number
- [ ] Every corner radius uses AppTheme.CornerRadius, not a literal
- [ ] Dark mode appearance is correct (no invisible text, no clashing backgrounds, no missing adaptations)
- [ ] Color contrast ratios meet WCAG AA (4.5:1 for body text, 3:1 for large text) in both modes
- [x] `pricingSurface` and `surface` are visually distinguishable in both light and dark mode

### Audit Result: 3/5

AppTheme is comprehensive and well-structured with adaptive colors for both modes. The token set covers colors, spacing, typography, corner radii, and sizing. Semantic naming is strong (`surface`, `surfaceElevated`, `accent`). However, ~16 violations are scattered across views.

**Violations found:**

- **2 critical dark mode violations.** StopwatchView.swift:131 uses `.foregroundStyle(.white)` — invisible on light backgrounds. ProductListView.swift:259 uses `.foregroundStyle(isSelected ? .white : .primary)` — breaks on dark mode accent backgrounds.
- **4 hardcoded red colors.** WorkStepDetailView.swift:310,315 and MaterialDetailView.swift:282,287 use `Color.red.opacity(0.1/0.3)` instead of `AppTheme.Colors.destructive`.
- **5 hardcoded spacing/sizing values.** PortfolioView.swift has magic numbers for bar heights (6px, 12px), legend dots (8x8), and minimum widths (2px). TemplatePickerView.swift:83 has `frame(height: 60)`.
- **1 hardcoded font size.** TemplatePickerView.swift:81 uses `.font(.system(size: 36))`.
- **1 hardcoded corner radius.** PortfolioView.swift:284 uses `cornerRadius: 3` instead of an AppTheme value.
- **Shadow parameters hardcoded.** ViewModifiers.swift:23 has `.shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)` inline.

---

## 3. Component Reuse & DRY Principles

**What to evaluate:** Are recurring UI patterns extracted into reusable components? Is there unnecessary duplication across views?

| Score | Criteria |
|-------|----------|
| 1 | Extensive copy-paste across views. Same layout/logic repeated 3+ times with minor variations. |
| 2 | Some components extracted but inconsistently used — e.g., a thumbnail helper exists but some views still inline their own image/placeholder logic. |
| 3 | Common patterns are extracted (thumbnails, input fields, card styles, section headers). Occasional duplication remains where views are similar but not identical. |
| 4 | All recurring patterns are components. List row layouts, form fields, hero cards, section headers, empty states — all use shared building blocks. No copy-paste duplication. |
| 5 | All of 4, plus: components have clean, minimal APIs. No "god components" with 10+ parameters. Component boundaries match conceptual boundaries (a component does one thing). |

**Specific checks:**
- [x] Thumbnail views (Product, WorkStep, Material) share a consistent pattern and are reused everywhere
- [ ] Currency input fields use `CurrencyInputField` everywhere, not ad-hoc TextField + symbol combinations
- [ ] Percentage fields use `PercentageInputField` everywhere with consistent focus/format behavior
- [x] Card styling uses `.cardStyle()` modifier — no inline card implementations
- [x] Hero value display uses `.heroCardStyle()` — no ad-hoc accent-colored large-text blocks
- [x] Section grouping uses `.sectionGroupStyle()` — consistent across all detail/calculator views
- [x] Empty states follow a consistent pattern (ContentUnavailableView with guidance text)
- [ ] Form validation logic (required fields, numeric clamping) is not duplicated across form views
- [x] Detail row layout (label + value) uses `DetailRow` or equivalent — not repeated inline
- [ ] "Used By" product list display uses a shared pattern across WorkStepDetailView and MaterialDetailView

### Audit Result: 2/5

Common building blocks (thumbnails, DetailRow, card modifiers, empty states) are well-extracted and consistently used. But the app has a massive structural duplication problem — the WorkStep and Material feature hierarchies are nearly identical with ~1,200 lines of duplicated code.

**Violations found:**

- **WorkStepListView vs MaterialListView: 93% structural overlap.** 400+ lines each with nearly identical logic for sorted links, empty states, row rendering, reorder rows, buffer sections, focus/blur handlers, and existing-item picker sheets.
- **WorkStepDetailView vs MaterialDetailView: 83% overlap.** 300+ lines each with identical patterns for header, info section, product settings, "Used By" section, and remove button.
- **WorkshopView vs MaterialsLibraryView: 92% overlap.** ~100 lines each with identical query, search, empty state, and list rendering.
- **WorkStepFormView vs MaterialFormView: 70% overlap.** Init patterns, photo picker, details section, save logic, and loadPhoto() are structurally identical.
- **2 inline CurrencyInputField violations.** MaterialFormView.swift:136-144 and SettingsView.swift:42-59 build manual HStack + TextField + symbol instead of using the shared component.
- **2 inline buffer percentage input violations.** WorkStepListView.swift:256-264 and MaterialListView.swift:255-264 duplicate identical buffer input with identical focus/blur logic instead of extracting a shared BufferInputSection component.

These parallel hierarchies mean every bug fix or UI change must be applied in two places. A generic `ItemListView<T>`, `ItemDetailView<T>`, and `LibraryView<T>` would eliminate ~1,200 lines.

---

## 4. Data Model Design & Integrity

**What to evaluate:** Are SwiftData models well-structured? Are relationships correct? Are defaults safe? Is the schema robust against edge cases?

| Score | Criteria |
|-------|----------|
| 1 | Models have incorrect relationships, missing delete rules, or allow invalid states (e.g., negative quantities without guards). |
| 2 | Relationships and delete rules are defined but some edge cases are unhandled — e.g., orphaned join models, missing cascade rules, defaults that allow division-by-zero. |
| 3 | All relationships have correct delete rules. Defaults prevent division-by-zero. Join models properly enable many-to-many. Minor issues like redundant properties or inconsistent naming. |
| 4 | Schema is clean and minimal. Every property has a clear purpose. Defaults are safe. Delete rules are comprehensive. No redundant data. Naming is consistent across all models. |
| 5 | All of 4, plus: schema supports future evolution (e.g., adding a new platform type, a new cost category) without migration pain. No stringly-typed fields that should be enums. Relationships are documented in code or immediately obvious from naming. |

**Specific checks:**
- [x] No explicit `id: UUID` on any model (uses `persistentModelID`)
- [x] `batchUnitsCompleted` and `bulkQuantity` default to 1 (division-by-zero guard)
- [x] All delete rules are explicitly set (no implicit defaults): Product→joins cascade, Category→products nullify
- [x] Join models (ProductWorkStep, ProductMaterial) have correct bidirectional relationships
- [x] `PlatformType` is a proper enum, not a raw string
- [x] No model stores derived/calculated values that should be computed by CostingEngine
- [x] All Decimal fields that represent money or percentages use `Decimal`, never `Double`
- [x] `summary` is used consistently instead of `description` across all models
- [ ] ProductPricing enforces at most one record per product per platform (or handles duplicates gracefully)
- [x] ModelContainer schema includes all 8 model types

### Audit Result: 4/5

The schema is clean, well-documented, and carefully designed. Relationships and delete rules are comprehensive and correct. Defaults are safe. Every property has a clear purpose.

**Violations found:**

- **No unique constraint on ProductPricing for product+platform.** Code uses `.first(where:)` to check before creating, but nothing prevents duplicates at the model level if created through other code paths.
- **Legacy dead files.** CategoryListView.swift (79 lines) and CategoryFormView.swift (59 lines) are orphaned — functional but unreachable from the current navigation. CLAUDE.md acknowledges them as "legacy" but they're still compiled into the binary.

**Passes (9 of 10 checks):** No explicit UUID ids. Safe defaults preventing division-by-zero. All delete rules correct. Proper enum for PlatformType. Pure data models with no derived values. Consistent `Decimal` usage. `summary` naming convention followed. All 8 models registered in schema.

---

## 5. Calculation Engine Correctness & Design

**What to evaluate:** Is CostingEngine complete, correct, and well-structured? Are edge cases handled? Are the dual overloads (model + raw-value) consistent?

| Score | Criteria |
|-------|----------|
| 1 | Calculations are scattered across views and models. No central engine. Results are inconsistent between different parts of the app. |
| 2 | CostingEngine exists but is incomplete — some calculations are still inline in views. Edge cases (zero division, nil pricing) are handled inconsistently. |
| 3 | All calculations route through CostingEngine. Division-by-zero guards are in place. Model and raw-value overloads exist for key functions. Minor inconsistencies in naming or parameter ordering. |
| 4 | Engine is comprehensive, consistent, and well-organized. Functions are grouped logically (per-step → per-product → per-batch → portfolio). Every function that has a model overload also has a raw-value overload. All edge cases return safe values (nil, zero) rather than crashing. |
| 5 | All of 4, plus: function signatures are self-documenting. Parameter names make the formula obvious. No hidden coupling between functions. The engine could be extracted into a standalone Swift package with zero changes. |

**Specific checks:**
- [x] Every division operation is guarded against zero
- [x] `targetRetailPrice` returns nil when denominator ≤ 0 (not a crash, not infinity)
- [x] `actualProfitMargin` returns nil when gross revenue is 0
- [x] `bulkPurchasesNeeded` returns (0, 0, 0) when bulkQuantity ≤ 0
- [x] Model overloads and raw-value overloads produce identical results for the same inputs
- [x] Batch functions are strictly `perUnitFunction × batchSize` (no independent math)
- [x] Portfolio snapshot reuses existing engine functions (no duplicate calculation logic)
- [x] `resolvedFees` correctly merges locked platform constants with user-editable values
- [x] Formatting functions (formatHours, formatDuration, formatHoursReadable) handle zero, negative, and very large values
- [ ] No floating-point `Double` used for monetary calculations anywhere in the engine

### Audit Result: 3/5

CostingEngine is well-organized as a caseless enum with comprehensive functions. All 14+ division operations are properly guarded. The dual-overload pattern is consistent. But it has a dependency violation, is incomplete (views compute things the engine should own), and has an efficiency issue.

**Violations found:**

- **CostingEngine imports SwiftData.** Violates pure-logic principle. The engine receives model objects as parameters and doesn't need the import itself. This prevents extracting the engine into a standalone Swift package.
- **Missing functions for view-level calculations.** The engine lacks functions for: batch labor/material/shipping cost breakdown (BatchForecastView computes inline), per-fee-line dollar amounts (PricingCalculatorView computes inline), cost fraction proportions (PortfolioView computes inline), and total percent fees (PricingCalculatorView computes inline). These calculations are only testable through UI testing, not unit testing.
- **N+1 traversal in `productSnapshot()`.** Calls `totalLaborCostBuffered()`, `totalMaterialCostBuffered()`, `totalProductionCost()`, and `totalLaborHours()` separately — each traverses the product's relationships independently. `portfolioSnapshots()` calls this across all products, producing ~500 redundant relationship accesses for 50 products.

**Passes (9 of 10 checks):** All divisions guarded. Nil returns for impossible calculations. Batch functions delegate to per-unit functions. resolvedFees merges locked/user values. Formatting functions handle edge cases. Portfolio snapshot reuses existing functions.

---

## 6. Error Handling & Defensive Programming

**What to evaluate:** Does the app handle unexpected states gracefully? Are optionals handled safely? Does the app crash-proof itself against bad data?

| Score | Criteria |
|-------|----------|
| 1 | Force-unwraps throughout. No handling of nil optionals, empty arrays, or missing relationships. App would crash on common edge cases. |
| 2 | Most force-unwraps removed but some remain. Nil-coalescing used inconsistently. Some views crash or display garbage when data is missing. |
| 3 | Optionals handled safely with nil-coalescing or conditional binding. Views degrade gracefully for missing data (empty states, placeholder text). No force-unwraps in production code. |
| 4 | All of 3, plus: edge cases are explicitly handled (empty product, no pricing, zero labor hours). Error states are user-friendly, not technical. The app never shows raw "nil" or "NaN" to the user. |
| 5 | All of 4, plus: defensive programming is systematic, not ad-hoc. There is a clear pattern for how each layer handles missing/invalid data (models default safely, engine returns nil/zero, views show empty states). |

**Specific checks:**
- [ ] Zero force-unwraps (`!`) in production code (tests are acceptable)
- [ ] No `try!` or `fatalError()` in production code
- [x] Views handle empty `productWorkSteps` / `productMaterials` arrays (show empty state, not a blank screen)
- [x] Pricing calculator handles missing ProductPricing (lazy creation, not crash)
- [x] Portfolio view handles mix of priced and unpriced products
- [x] Batch forecast handles product with no steps, no materials, or no pricing
- [x] Template application handles duplicate titles gracefully (dedup, not crash)
- [x] Currency formatting handles zero, negative, and very large Decimal values
- [ ] ModelContainer creation handles schema migration failure (recovery, not crash)
- [x] StopwatchView handles rapid start/stop without race conditions

### Audit Result: 3/5

Division guards and empty-array handling are excellent. Template application is robust. Lazy pricing creation and decimal parsing fallbacks are well-implemented. But there are 4 force unwraps in hot view paths and a fatalError that crashes the app on startup.

**Violations found:**

- **4 force unwraps in production view code.** WorkStepListView.swift:186,216 (`link.workStep!`) and MaterialListView.swift:185,215 (`link.material!`) in row-rendering functions. While a nil check exists earlier in the ForEach, these force unwraps in separate functions have no local guard — a SwiftData relationship fault between the check and the render would crash.
- **`fatalError()` in app startup.** MakerMarginsApp.swift:40 — if ModelContainer creation fails after store reset, the app crashes permanently with no recovery UI. A user with a corrupted store has no way to use the app.

**Passes (7 of 10 checks):** Zero `try!`. All empty arrays produce meaningful empty states. Pricing records created lazily. Portfolio handles priced/unpriced mix. Batch forecast degrades gracefully. Template dedup robust. Decimal parsing uses `?? 0` fallbacks throughout.

---

## 7. Test Coverage & Quality

**What to evaluate:** Are tests comprehensive, reliable, and well-structured? Do they catch real bugs? Are they maintainable?

| Score | Criteria |
|-------|----------|
| 1 | Few or no tests. Tests that exist are brittle, test implementation details, or don't assert meaningful outcomes. |
| 2 | Tests exist for happy paths but skip edge cases. Some tests are redundant or test trivial behavior. No integration tests. |
| 3 | Good coverage of CRUD operations, calculation correctness, and cascade deletes. Edge cases tested for core engine functions. Tests are organized by epic. |
| 4 | Comprehensive coverage including: happy paths, edge cases (zero, nil, empty), boundary conditions, cascade behaviors, duplication logic, and cross-epic interactions. Tests are independent and reliable. |
| 5 | All of 4, plus: tests serve as living documentation — reading a test file explains the feature's behavior. Test helpers reduce boilerplate. No flaky tests. Test names clearly describe the scenario being verified. |

**Specific checks:**
- [ ] Every CostingEngine function has at least one happy-path test and one edge-case test
- [x] Cascade delete rules are tested (delete product → joins removed, shared entities survive)
- [x] Product duplication is tested (metadata copied, shared entities re-linked, pricing copied)
- [x] Template deduplication is tested (same title reuses entity, cross-template overlap handled)
- [x] Division-by-zero guards are tested explicitly
- [x] Model overload and raw-value overload consistency is tested
- [x] Tests use in-memory ModelContainer (not persisted storage)
- [x] Tests use Swift Testing framework (@Test macros), not XCTest
- [x] Test file organization matches epic structure
- [x] No test depends on execution order of other tests

### Audit Result: 3/5

152 tests is an impressive count, well-organized by epic, with perfect framework usage and isolation. CRUD operations, core calculations, cascade deletes, and duplication are thoroughly covered. But meaningful gaps exist in formatter testing, manager testing, and cross-platform coverage.

**Violations found:**

- **`formatDuration()` and `formatHours()` have zero tests.** These format critical financial data in views but are never verified in the test suite.
- **AppearanceManager has zero tests.** Default setting, UserDefaults persistence, resolvedColorScheme — all untested. (LaborRateManager and CurrencyFormatter are tested.)
- **`resolvedFees()` missing 2 of 4 platforms.** Etsy and General tested; Shopify and Amazon not. A bug in Shopify's locked fee resolution would ship undetected.
- **Portfolio metrics only tested for General platform.** `portfolioSnapshots()` and `portfolioAverages()` never run against Etsy/Shopify/Amazon fee structures.
- **`totalLaborCostBuffered()` and `totalMaterialCostBuffered()` have no dedicated tests.** Exercised indirectly through aggregates but never verified in isolation.
- **Negative input values undertested.** Negative `laborRate`, `unitsRequiredPerProduct`, and `bulkCost` are never tested — unclear if the engine handles them or produces nonsensical results.

**Passes (8 of 10 checks):** Cascade deletes tested for all 6 relationship types. Duplication tested for all critical fields. Template dedup tested thoroughly. 19 zero/nil edge case tests. Perfect framework and isolation. Test names are descriptive and self-documenting.

---

## 8. Naming Conventions & Code Readability

**What to evaluate:** Are names clear, consistent, and self-documenting? Can a new developer understand the code without extensive comments?

| Score | Criteria |
|-------|----------|
| 1 | Cryptic abbreviations, inconsistent casing, generic names (e.g., `data`, `value`, `item`). Comments required to understand basic flow. |
| 2 | Some clear names but inconsistency across files — different conventions for similar concepts (e.g., `cost` vs `price` vs `amount` used interchangeably). |
| 3 | Naming is mostly clear and consistent. Domain terms are used correctly (cost vs price, buffer vs margin). Minor inconsistencies exist but don't cause confusion. |
| 4 | All names are precise and domain-appropriate. Variables, functions, types, and files follow consistent conventions. Code reads like prose for the business domain. |
| 5 | All of 4, plus: naming is so clear that comments are unnecessary except for non-obvious business rules. File names, type names, and function names form a navigable map of the codebase. |

**Specific checks:**
- [x] `summary` used consistently (never `description` on models)
- [x] `Decimal` parameters for money are named with their unit context (e.g., `laborRate`, `bulkCost`, not just `rate`, `cost`)
- [x] Join model names clearly indicate the relationship (ProductWorkStep, not ProductStep or StepLink)
- [x] View files are named by their function (ProductFormView, not ProductSheet or ProductEditor)
- [x] CostingEngine functions follow verb-noun pattern (e.g., `totalLaborCost`, `targetRetailPrice`)
- [x] Boolean properties/functions use `is`/`has` prefix (e.g., `hasPricing`, `isPlatformFeeEditable`)
- [x] Enum cases are lowerCamelCase; enum types are UpperCamelCase
- [x] File organization matches the directory layout documented in CLAUDE.md
- [ ] No orphaned/dead code (unused functions, commented-out blocks, legacy files still referenced)
- [x] Comments explain "why" not "what" — the code explains what

### Audit Result: 4/5

Naming is precise, domain-appropriate, and consistent. The codebase reads cleanly for the business domain. CostingEngine functions follow clear patterns. Zero TODO/FIXME/DEBUG comments — the codebase is clean.

**Violations found:**

- **Dead code files.** CategoryListView.swift (79 lines) and CategoryFormView.swift (59 lines) are acknowledged as legacy in CLAUDE.md but still ship in the binary. They are functional views that are unreachable from the current navigation structure and should be deleted.
- **A few generic variable names** in narrow scopes (e.g., `value` in PricingCalculatorView guard clauses). Acceptable in limited scope but not exemplary.

**Passes (9 of 10 checks):** `summary` consistent. Monetary parameters contextually named. Join models clearly named. View files named by function. CostingEngine follows verb-noun pattern. Booleans use `is`/`has`. Enum casing correct. File organization matches CLAUDE.md. Comments explain "why."

---

## 9. Performance & Resource Management

**What to evaluate:** Does the app avoid unnecessary work? Are SwiftData queries efficient? Are images handled responsibly?

| Score | Criteria |
|-------|----------|
| 1 | O(n^2) loops, redundant queries on every view render, unbounded image loading, no consideration of memory. |
| 2 | Most operations are reasonable but some hot paths are inefficient — e.g., re-querying all products on every keystroke, loading all images into memory simultaneously. |
| 3 | Queries are appropriate for the data scale. Images are loaded lazily where possible. No obvious performance bottlenecks for a typical catalog (< 100 products). |
| 4 | All of 3, plus: calculated values that don't change per-render are not recomputed unnecessarily. SwiftData queries use appropriate predicates. Image data is compressed before storage. |
| 5 | All of 4, plus: the app would perform well with 500+ products. Scroll performance is smooth. Memory footprint is predictable. Template application is fast even with dedup queries. |

**Specific checks:**
- [x] SwiftData `@Query` is used at the appropriate granularity (not fetching all entities when only a subset is needed)
- [x] Image blobs use JPEG compression (not raw PNG data) for storage
- [ ] Portfolio snapshot computation doesn't trigger N+1 query patterns
- [x] List views use lazy loading (LazyVStack/LazyVGrid) for large collections
- [x] CostingEngine functions don't re-fetch from SwiftData on each call (models are passed in)
- [x] Stopwatch uses `TimelineView` efficiently (not re-rendering the entire view tree)
- [x] Template dedup fetches all entities once, then filters in-memory (not N queries)
- [x] No `@Query` in deeply nested subviews that could cause redundant fetches
- [x] Form views don't trigger model saves on every keystroke (save on dismiss/commit)
- [x] Search filtering is in-memory (not re-querying SwiftData on each character)

### Audit Result: 3/5

Queries, image handling, and list rendering are appropriate for the app's current scale (<100 products). Most performance patterns are solid. But the portfolio computation has a known efficiency issue that would degrade with a growing catalog.

**Violations found:**

- **N+1 risk in portfolio snapshot computation.** `CostingEngine.productSnapshot()` calls `totalLaborCostBuffered()`, `totalMaterialCostBuffered()`, `totalProductionCost()`, and `totalLaborHours()` separately — each traverses `productWorkSteps` and `productMaterials` independently. `portfolioSnapshots()` maps this across all products. For 50 products with 5 steps and 5 materials each, that's ~500 redundant relationship accesses per view refresh.
- **Search filtering is in-memory** across all library views (WorkshopView, MaterialsLibraryView, ProductListView). Fine for <100 items but won't scale to 500+. No SwiftData predicate-based filtering.

**Passes (9 of 10 checks):** @Query at correct granularity. JPEG compression at 0.8. LazyVGrid for grids. Engine receives models as parameters. TimelineView efficient. Template dedup fetches once. No nested @Query. Forms save on dismiss. Search is real-time in-memory.

---

## 10. Accessibility & Assistive Technology (Code Implementation)

**What to evaluate:** Does the code implement the accessibility APIs needed for VoiceOver, Dynamic Type, Switch Control, and other assistive technologies? (The UI/UX rubric evaluates the *design intent* — this evaluates whether the *code delivers* on it.)

| Score | Criteria |
|-------|----------|
| 1 | No accessibility implementation. Custom views have no labels. VoiceOver reads raw view hierarchies. Dynamic Type is ignored. |
| 2 | Some `accessibilityLabel` calls exist on buttons and icons, but custom components (hero cards, proportional bars, stopwatch display) are opaque to VoiceOver. Dynamic Type partially works but breaks on custom layouts. |
| 3 | All interactive elements have accessibility labels. Standard SwiftUI controls inherit system accessibility. Custom text displays (hero values, formatted costs) have explicit labels. Dynamic Type works for body text and most headers. |
| 4 | All of 3, plus: composite views are grouped logically for VoiceOver (a card reads as one element, not 5 separate labels). Decorative images are hidden. Value displays include context ("Target price: $45.00", not just "$45.00"). Dynamic Type scales gracefully across all screens including hero values. |
| 5 | All of 4, plus: custom components (stopwatch, proportional bars, stacked cost bars) have rich VoiceOver descriptions. Accessibility actions replace gesture-only interactions. Switch Control can operate the full app. The app passes Xcode's Accessibility Inspector audit with zero warnings. |

**Specific checks:**
- [ ] All custom buttons and icons have `accessibilityLabel` (not relying on SF Symbol names as labels)
- [ ] Hero value cards have `accessibilityLabel` that includes context (e.g., "Your Earnings per Sale: $12.50", not just "$12.50")
- [ ] Stopwatch display has `accessibilityValue` that updates with the running time ("2 minutes, 30 seconds")
- [ ] Stopwatch state changes post `accessibilityNotification` (e.g., "Timer started", "Timer paused")
- [ ] Decorative images (placeholders, template icons) use `.accessibilityHidden(true)`
- [ ] Product/step/material thumbnails with actual images have descriptive labels
- [ ] Composite cards use `.accessibilityElement(children: .combine)` or manual grouping to avoid chatty VoiceOver
- [ ] Proportional bars in PortfolioView have `accessibilityLabel` describing the value and rank ("Cutting Board: $12.50 earnings, rank 1 of 5")
- [ ] Stacked cost bars have `accessibilityLabel` describing the breakdown ("Labor 45%, Materials 35%, Shipping 20%")
- [ ] Swipe-to-delete and context menu actions are also available via `accessibilityAction` or visible buttons
- [ ] Reorder arrows have labels ("Move Sanding step up", not just "Up arrow")
- [ ] Platform picker segments have labels that include locked/editable context for VoiceOver
- [ ] Locked fee values announce as read-only ("Etsy platform fee: 6.5%, set by platform, not editable")
- [ ] Dynamic Type: all `AppTheme.Typography` values use scalable text styles (not fixed `Font.system(size:)`)
- [ ] Dynamic Type: hero values and cards don't clip or overlap at `.accessibility5` size
- [ ] Dynamic Type: form layouts reflow gracefully at large sizes (labels stack above fields if needed)
- [x] Color is never the sole state indicator — green/red profit also uses +/- prefix or explicit "profit"/"loss" label
- [ ] `@Environment(\.accessibilityReduceMotion)` is checked before any non-essential animation
- [ ] Touch targets for small elements (reorder arrows, +/- batch buttons, chip filters) meet 44×44pt minimum
- [ ] `accessibilityHint` is provided for non-obvious actions ("Double tap to start timing this work step")
- [ ] Form field labels are programmatically associated with their inputs (not just visually adjacent)

### Audit Result: 1/5

This is the weakest dimension by a wide margin. The app has effectively zero accessibility implementation. VoiceOver would be unusable for custom components. This is the highest App Store rejection risk.

**Violations found:**

- **Only 4 `accessibilityLabel` instances in the entire app** (2 in PortfolioView, 1 in PricingCalculatorView, 1 info button). All custom buttons (reorder arrows, +/- batch, menu icons, chip filters) have no labels — VoiceOver reads "Button" with no context.
- **Zero `accessibilityValue` instances.** The stopwatch timer, hero earnings values, proportional bars, and all dynamic numerical displays have no accessible values.
- **Zero `accessibilityHint` instances.** No guidance for complex interactions.
- **Only 1 `accessibilityHidden` instance** (decorative icon in CalculatorSectionHeader). All placeholder thumbnails, chevron icons, and decorative images are announced by VoiceOver.
- **Only 2 `accessibilityElement` groupings** (both in PortfolioView). All other composite views read as fragmented individual elements.
- **Zero `accessibilityAction` instances.** Swipe-to-delete, context menus, and reorder are gesture-only — no alternatives for Switch Control or voice-command users.
- **Zero `reduceMotion` checks.** Animations in reorder toggle and stopwatch updates ignore the system setting.
- **1 hardcoded font size.** `timerDisplay` at fixed 56pt won't scale with Dynamic Type.
- **6+ touch targets below 44x44pt minimum.** Reorder arrows, batch +/- buttons, plus-circle buttons, menu dots, and category chips.

**Single pass (1 of 21 checks):** Color is not the sole indicator for profit — numbers always appear alongside green/red, and negative values show "-$" prefix. Everything else fails.

---

## 11. Build Pipeline & Project Configuration

**What to evaluate:** Is the CI pipeline reliable? Is the project configuration clean and reproducible?

| Score | Criteria |
|-------|----------|
| 1 | No CI. Project file is manually maintained and often broken. No .gitignore for build artifacts. |
| 2 | CI exists but is fragile — breaks on Xcode updates, doesn't run tests, or has manual steps. |
| 3 | CI builds and tests on every push. XcodeGen generates the project. .gitignore excludes build artifacts. Test results are accessible. |
| 4 | All of 3, plus: CI uses a specific simulator device, handles platform downloads, uploads test artifacts. Pipeline is self-healing (recreates simulator if missing). |
| 5 | All of 4, plus: CI catches schema registration errors, missing files, and import failures automatically. Build warnings are treated as signal. Pipeline completes in a reasonable time (< 15 min). |

**Specific checks:**
- [x] `.xcodeproj` is in `.gitignore` (generated by XcodeGen)
- [x] `project.yml` accurately reflects the current file structure
- [x] CI workflow runs on every push to relevant branches
- [x] CI creates a concrete simulator (not "any simulator" — prevents flaky failures)
- [x] CI runs the full test suite (not just build)
- [x] Test result artifacts (`.xcresult`) are uploaded for debugging
- [x] CI handles iOS platform download (not assumed pre-installed)
- [x] `CODE_SIGNING_ALLOWED=NO` is set (no signing in CI)
- [x] No secrets or credentials in the repository
- [ ] Build succeeds with zero warnings (or warnings are tracked and intentional)

### Audit Result: 4/5

The CI pipeline is solid and well-configured. It handles the full build-test cycle reliably with proper artifact upload and concrete simulator selection.

**Violations found:**

- **Deployment target mismatch.** project.yml targets iOS 26.0 (intentional per CLAUDE.md for Liquid Glass), but CI runs against an iOS 18 simulator runtime. Builds compile against a different SDK than the actual deployment target, which could mask iOS 26-specific API issues.

**Passes (9 of 10 checks):** .xcodeproj gitignored. project.yml reflects structure. CI runs every push. Concrete iPhone 16 simulator by UDID. Full test suite runs. .xcresult uploaded with `if: always()`. Platform download handled. CODE_SIGNING_ALLOWED=NO. No secrets in repo.

---

## Scoring Summary Template

| # | Dimension | Score (1-5) | Key Issue |
|---|-----------|-------------|-----------|
| 1 | Architecture & Separation of Concerns | **3** | 13+ inline calculations in views, display logic in model |
| 2 | Design Token System & Theming | **3** | 16 violations including 2 dark mode breaks |
| 3 | Component Reuse & DRY Principles | **2** | ~1,200 lines structural duplication across WorkStep/Material |
| 4 | Data Model Design & Integrity | **4** | No unique constraint on ProductPricing; 2 dead files |
| 5 | Calculation Engine Correctness & Design | **3** | Imports SwiftData; missing functions views compute inline |
| 6 | Error Handling & Defensive Programming | **3** | 4 force unwraps, 1 fatalError on app startup |
| 7 | Test Coverage & Quality | **3** | Formatters untested, AppearanceManager untested, 2/4 platforms |
| 8 | Naming Conventions & Code Readability | **4** | Dead legacy files still in target |
| 9 | Performance & Resource Management | **3** | N+1 in portfolio snapshots |
| 10 | Accessibility & Assistive Technology | **1** | Effectively no implementation |
| 11 | Build Pipeline & Project Configuration | **4** | Deployment target vs CI runtime mismatch |
| | **Total** | **33/55** | |

**Rating: Needs targeted work before production** (33–41 range)

**Audit date:** 2026-04-04

**Rating scale:**
- 49–55: Ship with confidence
- 42–48: Ship-ready with minor improvements
- 33–41: Needs targeted work before production
- 22–32: Significant gaps — address before beta
- < 22: Not production-ready

---

## Top 3 Actions to Raise Score

1. **Accessibility (1 → 3 = +2 points).** Add `accessibilityLabel` to all buttons and hero values, `accessibilityHidden` on decorative elements, fix touch targets to 44x44pt, check `reduceMotion`. This is the highest App Store rejection risk and the single largest score drag.

2. **Component Reuse (2 → 3 = +1 point).** Extract generic `ItemListView<T>` and `ItemDetailView<T>` to eliminate the WorkStep/Material parallel hierarchy duplication (~1,200 lines). Also reduces future maintenance cost for every bug fix and feature change.

3. **Architecture leaks (3 → 4 = +1 point).** Move the 13+ inline calculations from views into CostingEngine functions. Move PlatformFeeProfile display helpers to a formatter or view extension. Remove SwiftData import from CostingEngine.
