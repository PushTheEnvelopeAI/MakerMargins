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
- [ ] No arithmetic in SwiftUI view bodies (all math routes through CostingEngine)
- [ ] No `NumberFormatter` / `String(format:)` in views (all formatting routes through CurrencyFormatter or CostingEngine.formatHours)
- [ ] Models contain zero display logic (no computed properties that format strings for UI)
- [ ] CostingEngine has zero SwiftData imports (pure logic, testable without a ModelContainer)
- [ ] Managers (CurrencyFormatter, AppearanceManager, LaborRateManager) follow a single consistent pattern
- [ ] No view directly reads UserDefaults — all persistence routes through managers

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
- [ ] `pricingSurface` and `surface` are visually distinguishable in both light and dark mode

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
- [ ] Thumbnail views (Product, WorkStep, Material) share a consistent pattern and are reused everywhere
- [ ] Currency input fields use `CurrencyInputField` everywhere, not ad-hoc TextField + symbol combinations
- [ ] Percentage fields use `PercentageInputField` everywhere with consistent focus/format behavior
- [ ] Card styling uses `.cardStyle()` modifier — no inline card implementations
- [ ] Hero value display uses `.heroCardStyle()` — no ad-hoc accent-colored large-text blocks
- [ ] Section grouping uses `.sectionGroupStyle()` — consistent across all detail/calculator views
- [ ] Empty states follow a consistent pattern (ContentUnavailableView with guidance text)
- [ ] Form validation logic (required fields, numeric clamping) is not duplicated across form views
- [ ] Detail row layout (label + value) uses `DetailRow` or equivalent — not repeated inline
- [ ] "Used By" product list display uses a shared pattern across WorkStepDetailView and MaterialDetailView

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
- [ ] No explicit `id: UUID` on any model (uses `persistentModelID`)
- [ ] `batchUnitsCompleted` and `bulkQuantity` default to 1 (division-by-zero guard)
- [ ] All delete rules are explicitly set (no implicit defaults): Product→joins cascade, Category→products nullify
- [ ] Join models (ProductWorkStep, ProductMaterial) have correct bidirectional relationships
- [ ] `PlatformType` is a proper enum, not a raw string
- [ ] No model stores derived/calculated values that should be computed by CostingEngine
- [ ] All Decimal fields that represent money or percentages use `Decimal`, never `Double`
- [ ] `summary` is used consistently instead of `description` across all models
- [ ] ProductPricing enforces at most one record per product per platform (or handles duplicates gracefully)
- [ ] ModelContainer schema includes all 8 model types

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
- [ ] Every division operation is guarded against zero
- [ ] `targetRetailPrice` returns nil when denominator ≤ 0 (not a crash, not infinity)
- [ ] `actualProfitMargin` returns nil when gross revenue is 0
- [ ] `bulkPurchasesNeeded` returns (0, 0, 0) when bulkQuantity ≤ 0
- [ ] Model overloads and raw-value overloads produce identical results for the same inputs
- [ ] Batch functions are strictly `perUnitFunction × batchSize` (no independent math)
- [ ] Portfolio snapshot reuses existing engine functions (no duplicate calculation logic)
- [ ] `resolvedFees` correctly merges locked platform constants with user-editable values
- [ ] Formatting functions (formatHours, formatDuration, formatHoursReadable) handle zero, negative, and very large values
- [ ] No floating-point `Double` used for monetary calculations anywhere in the engine

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
- [ ] Views handle empty `productWorkSteps` / `productMaterials` arrays (show empty state, not a blank screen)
- [ ] Pricing calculator handles missing ProductPricing (lazy creation, not crash)
- [ ] Portfolio view handles mix of priced and unpriced products
- [ ] Batch forecast handles product with no steps, no materials, or no pricing
- [ ] Template application handles duplicate titles gracefully (dedup, not crash)
- [ ] Currency formatting handles zero, negative, and very large Decimal values
- [ ] ModelContainer creation handles schema migration failure (recovery, not crash)
- [ ] StopwatchView handles rapid start/stop without race conditions

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
- [ ] Cascade delete rules are tested (delete product → joins removed, shared entities survive)
- [ ] Product duplication is tested (metadata copied, shared entities re-linked, pricing copied)
- [ ] Template deduplication is tested (same title reuses entity, cross-template overlap handled)
- [ ] Division-by-zero guards are tested explicitly
- [ ] Model overload and raw-value overload consistency is tested
- [ ] Tests use in-memory ModelContainer (not persisted storage)
- [ ] Tests use Swift Testing framework (@Test macros), not XCTest
- [ ] Test file organization matches epic structure
- [ ] No test depends on execution order of other tests

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
- [ ] `summary` used consistently (never `description` on models)
- [ ] `Decimal` parameters for money are named with their unit context (e.g., `laborRate`, `bulkCost`, not just `rate`, `cost`)
- [ ] Join model names clearly indicate the relationship (ProductWorkStep, not ProductStep or StepLink)
- [ ] View files are named by their function (ProductFormView, not ProductSheet or ProductEditor)
- [ ] CostingEngine functions follow verb-noun pattern (e.g., `totalLaborCost`, `targetRetailPrice`)
- [ ] Boolean properties/functions use `is`/`has` prefix (e.g., `hasPricing`, `isPlatformFeeEditable`)
- [ ] Enum cases are lowerCamelCase; enum types are UpperCamelCase
- [ ] File organization matches the directory layout documented in CLAUDE.md
- [ ] No orphaned/dead code (unused functions, commented-out blocks, legacy files still referenced)
- [ ] Comments explain "why" not "what" — the code explains what

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
- [ ] SwiftData `@Query` is used at the appropriate granularity (not fetching all entities when only a subset is needed)
- [ ] Image blobs use JPEG compression (not raw PNG data) for storage
- [ ] Portfolio snapshot computation doesn't trigger N+1 query patterns
- [ ] List views use lazy loading (LazyVStack/LazyVGrid) for large collections
- [ ] CostingEngine functions don't re-fetch from SwiftData on each call (models are passed in)
- [ ] Stopwatch uses `TimelineView` efficiently (not re-rendering the entire view tree)
- [ ] Template dedup fetches all entities once, then filters in-memory (not N queries)
- [ ] No `@Query` in deeply nested subviews that could cause redundant fetches
- [ ] Form views don't trigger model saves on every keystroke (save on dismiss/commit)
- [ ] Search filtering is in-memory (not re-querying SwiftData on each character)

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
- [ ] Color is never the sole state indicator — green/red profit also uses +/- prefix or explicit "profit"/"loss" label
- [ ] `@Environment(\.accessibilityReduceMotion)` is checked before any non-essential animation
- [ ] Touch targets for small elements (reorder arrows, +/- batch buttons, chip filters) meet 44×44pt minimum
- [ ] `accessibilityHint` is provided for non-obvious actions ("Double tap to start timing this work step")
- [ ] Form field labels are programmatically associated with their inputs (not just visually adjacent)

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
- [ ] `.xcodeproj` is in `.gitignore` (generated by XcodeGen)
- [ ] `project.yml` accurately reflects the current file structure
- [ ] CI workflow runs on every push to relevant branches
- [ ] CI creates a concrete simulator (not "any simulator" — prevents flaky failures)
- [ ] CI runs the full test suite (not just build)
- [ ] Test result artifacts (`.xcresult`) are uploaded for debugging
- [ ] CI handles iOS platform download (not assumed pre-installed)
- [ ] `CODE_SIGNING_ALLOWED=NO` is set (no signing in CI)
- [ ] No secrets or credentials in the repository
- [ ] Build succeeds with zero warnings (or warnings are tracked and intentional)

---

## Scoring Summary Template

| # | Dimension | Score (1-5) | Key Issue |
|---|-----------|-------------|-----------|
| 1 | Architecture & Separation of Concerns | | |
| 2 | Design Token System & Theming | | |
| 3 | Component Reuse & DRY Principles | | |
| 4 | Data Model Design & Integrity | | |
| 5 | Calculation Engine Correctness & Design | | |
| 6 | Error Handling & Defensive Programming | | |
| 7 | Test Coverage & Quality | | |
| 8 | Naming Conventions & Code Readability | | |
| 9 | Performance & Resource Management | | |
| 10 | Accessibility & Assistive Technology | | |
| 11 | Build Pipeline & Project Configuration | | |
| | **Total** | **/55** | |

**Rating scale:**
- 49–55: Ship with confidence
- 42–48: Ship-ready with minor improvements
- 33–41: Needs targeted work before production
- 22–32: Significant gaps — address before beta
- < 22: Not production-ready
