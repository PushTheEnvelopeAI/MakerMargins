# Epic 2: Labor Engine & Stopwatch

**Status:** Complete — pending CI verification and manual testing
**Branch:** `epic_2` (from `epic_1`)

## Context

Epic 1 delivered Product & Category CRUD. Epic 2 adds the labor/workflow system — the core value driver of MakerMargins. Users need to define reusable work steps, time them, and see labor costs calculated automatically at the product level.

**Key design decision:** Work steps are **shared and reusable** across products. A maker with similar SKUs can define a step once (e.g., "Sanding") and assign it to multiple products. Editing a step from any context updates it everywhere. This requires changing the data model from one-to-many to many-to-many with a join model for per-product ordering.

---

## Schema Changes

### WorkStep (modified — shared entity, no longer owned by one product)
Remove `product: Product?` relationship. Add `productWorkSteps: [ProductWorkStep]` inverse.

### ProductWorkStep (new join model)
| Property | Type | Notes |
|----------|------|-------|
| product | Product? | Many-to-one |
| workStep | WorkStep? | Many-to-one |
| sortOrder | Int | Per-product ordering |

- Deleting a Product **cascade-deletes its ProductWorkStep entries** (associations), but NOT the WorkSteps themselves
- WorkSteps without associations remain in the library (accessible from Workshop tab)

### Product (modified)
- Replace `workSteps: [WorkStep]` with `productWorkSteps: [ProductWorkStep]` (cascade delete)
- Materials relationship unchanged

---

## Sub-Features Checklist

### SF-1 — Schema Changes + Default Labor Rate Setting ✅
- [x] New model: `ProductWorkStep` in `Models/ProductWorkStep.swift`
- [x] `WorkStep`: removed `product: Product?`, added `productWorkSteps: [ProductWorkStep]` (cascade)
- [x] `Product`: replaced `workSteps: [WorkStep]` with `productWorkSteps: [ProductWorkStep]` (cascade)
- [x] Registered `ProductWorkStep` in `MakerMarginsApp.swift` Schema array
- [x] `LaborRateManager` (`Engine/LaborRateManager.swift`): `@Observable @MainActor`, UserDefaults-persisted, EnvironmentKey
- [x] Injected `LaborRateManager` at app root in `MakerMarginsApp.swift`
- [x] "Labor" section in `SettingsView` with default hourly rate TextField + `/hr` suffix + footer
- [x] Updated `Epic1Tests` cascade delete test for new join model
- [x] Updated `ProductDetailView` delete confirmation message

**Files created:** `Models/ProductWorkStep.swift`, `Engine/LaborRateManager.swift`
**Files modified:** `Models/WorkStep.swift`, `Models/Product.swift`, `MakerMarginsApp.swift`, `Views/Settings/SettingsView.swift`, `Views/Products/ProductDetailView.swift`, `MakerMarginsTests/Epic1Tests.swift`

---

### SF-2 — CostingEngine (Labor Calculations) ✅
- [x] `enum CostingEngine` (caseless namespace) with all static functions
- [x] `unitTimeHours(step:)` + raw-value overload, zero-division guard
- [x] `stepLaborCost(step:)` + raw-value overload
- [x] `totalLaborCost(product:)` traverses ProductWorkStep join
- [x] `totalMaterialCost(product:)` stub returning 0 (Epic 3)
- [x] `totalProductionCost(product:)` with buffers
- [x] `formatDuration(_ seconds:)` → "Xh Ym Zs" format

**Files modified:** `Engine/CostingEngine.swift`

---

### SF-3 — WorkStepFormView (Create & Edit) ✅
- [x] Full form: image, details, time & batch, cost, live preview
- [x] Local `@State` with write-back-on-save pattern (matches ProductFormView)
- [x] h/m/s time entry with `:` colon separators and 52pt fields
- [x] "Use Stopwatch" button (wired to StopwatchView in SF-6)
- [x] Labor rate pre-filled from `LaborRateManager.defaultRate` for new steps
- [x] Real-time calculated preview via CostingEngine raw-value overloads
- [x] Create: inserts WorkStep + ProductWorkStep join link
- [x] Edit: updates WorkStep properties (propagates to all products)
- [x] `Product?` optional — nil creates standalone library step (for Workshop tab)
- [x] Section footers with helper text explaining fields
- [x] `/hr` suffix on labor rate field

**Files modified:** `Views/Labor/WorkStepFormView.swift`

---

### SF-4 — WorkStepListView + ProductDetailView Integration ✅
- [x] `WorkStepListView` as inline component in `ProductDetailView`
- [x] Steps sorted by `productWorkSteps.sortOrder`
- [x] Step rows: `WorkStepThumbnailView` + title + stepLaborCost + NavigationLink
- [x] Add menu: "New Step" (WorkStepFormView sheet) + "Add Existing Step" (picker sheet)
- [x] Existing step picker with usage count and empty state
- [x] Swipe-to-remove with confirmation (removes association, not step)
- [x] Drag-to-reorder via `List` + `.onMove` + persistent edit mode
- [x] Total labor footer with accent-colored CostingEngine total
- [x] Empty state placeholder text
- [x] `ProductDetailView`: labor section replaced, `.navigationDestination(for: WorkStep.self)` added

**Files modified:** `Views/Labor/WorkStepListView.swift`, `Views/Products/ProductDetailView.swift`

---

### SF-5 — WorkStepDetailView ✅
- [x] Scrollable hub: header, Time & Batch GroupBox, Cost GroupBox, Used By GroupBox
- [x] All calculations via CostingEngine + CurrencyFormatter
- [x] "Used By" section showing all linked products
- [x] Toolbar menu: Edit Step, Record Time (StopwatchView), Delete Step
- [x] Delete confirmation with shared-step warning
- [x] Accepts optional `Product?` for edit form context

**Files modified:** `Views/Labor/WorkStepDetailView.swift`

---

### SF-6 — StopwatchView ✅
- [x] Full-screen stopwatch as `.fullScreenCover`
- [x] 3-state machine: idle → running → stopped
- [x] `TimelineView(.periodic(from: .now, by: 0.1))` with `Date.now` diff for accuracy
- [x] `MM:SS.t` display (hours shown when > 0)
- [x] Start / Stop / Save / Discard / Re-record buttons
- [x] `onSave: (TimeInterval) -> Void` closure (decoupled from model)
- [x] Optional `stepTitle` parameter — displays "Timing: Step Name" context
- [x] Dismiss X button hidden while running
- [x] Wired into WorkStepDetailView (writes to `step.recordedTime`)
- [x] Wired into WorkStepFormView (writes to form's h/m/s @State fields)

**Files modified:** `Views/Labor/StopwatchView.swift`, `Views/Labor/WorkStepDetailView.swift`, `Views/Labor/WorkStepFormView.swift`

---

### SF-7 — Cost Summary Wiring & Workshop Tab ✅
- [x] `ProductCostSummaryCard`: labor line wired to `CostingEngine.totalLaborCost`, total wired to `totalProductionCost`
- [x] Materials line remains at 0 with "Available in Epic 3" note
- [x] `WorkshopView`: full implementation — `@Query` all steps, searchable, NavigationLink → WorkStepDetailView
- [x] Workshop rows: `WorkStepThumbnailView` + title + usage count + stepLaborCost
- [x] Workshop "+" creates standalone step (nil product)
- [x] Workshop empty state: "Tap + to create a step, or add steps from a product's detail view."
- [x] `ContentView`: Tab 2 placeholder replaced with `WorkshopView()`

**Files modified:** `Views/Products/ProductCostSummaryCard.swift`, `Views/Workshop/WorkshopView.swift`, `ContentView.swift`

---

### SF-8 — E2E Tests ✅
- [x] 12 tests across 4 groups (Swift Testing framework)
- [x] WorkStep CRUD: create/fetch with all properties
- [x] ProductWorkStep association with sortOrder
- [x] Shared step across two products — edit propagates
- [x] Reorder steps — sortOrder updates correctly
- [x] Delete product preserves shared step
- [x] Delete step cascades to associations
- [x] CostingEngine: unitTimeHours, zero guard, stepLaborCost, totalLaborCost, totalProductionCost
- [x] LaborRateManager UserDefaults round-trip

**Files modified:** `MakerMarginsTests/Epic2Tests.swift`

---

## Polish Pass (post SF-8) ✅

### Pass 1 — Functional fixes
- [x] Drag-to-reorder: restructured to `List` + `ForEach` + `.onMove` with persistent edit mode
- [x] Fixed `reindexSortOrder` stale data — filters by `persistentModelID` after delete
- [x] Renamed `ButtonStyle` → `StopwatchButtonVariant` (avoids SwiftUI protocol shadow)
- [x] Workshop empty state text corrected to match "+" button existence

### Pass 2 — UX polish
- [x] Form section footers with helper text for Time & Batch and Cost sections
- [x] Time entry: `:` colon separators, wider 52pt fields
- [x] Stopwatch: `stepTitle` parameter displays "Timing: Step Name"
- [x] Extracted `WorkStepThumbnailView` (shared component replacing 3 duplicates)
- [x] Settings labor rate: saves on focus loss/submit, not every keystroke; added `/hr` suffix + footer

---

## Key Design Decisions

- **Shared steps (many-to-many):** Steps are reusable across products. Edit once, updates everywhere. Workshop tab serves as the step library.
- **Join model (ProductWorkStep):** SwiftData many-to-many arrays have no guaranteed order. A join model with `sortOrder` is the only reliable way to support per-product step ordering while keeping steps shared.
- **Caseless `enum CostingEngine`:** Pure logic, no state. Prevents accidental instantiation.
- **Raw-value overloads on CostingEngine:** Form previews need calculations before a WorkStep is saved. Avoids creating throwaway model objects.
- **`onSave` closure for StopwatchView:** Used from two contexts (detail view writing to model, form writing to local state). A closure is cleaner than binding gymnastics.
- **Swipe-to-delete in step list removes association, not step:** Since steps are shared, deleting from one product shouldn't destroy the step for others. Explicit step deletion happens from WorkStepDetailView.
- **Workshop tab = step library:** Repurposed from "active production" to a cross-product step library for reuse and fast access.
- **`WorkStepThumbnailView`:** Shared reusable component (like `ProductThumbnailView` in Epic 1) replacing 3 duplicate implementations.

---

## Key Technical Notes

- **`Product?` on WorkStepFormView** — nil creates a standalone library step (no ProductWorkStep link). Workshop tab uses this.
- **`Product?` on WorkStepDetailView** — optional context for the edit form. Falls back to first linked product. Nil when navigated from Workshop tab.
- **Persistent edit mode on step list** — `List` with `.environment(\.editMode, .constant(.active))` + `.scrollDisabled(true)` for drag handles inside a GroupBox within a ScrollView.
- **Settings labor rate** — saves on focus loss (`@FocusState` + `onChange(of: focused)`) or submit, not on every keystroke.

---

## Verification

1. **CI:** Push to `epic_2` → GitHub Actions: XcodeGen → build → all Epic1Tests + Epic2Tests pass
2. **Manual (MacInCloud):**
   - Create a WorkStep from a product's detail view
   - Fill out all fields, see real-time cost preview
   - Use the stopwatch to record time, save it
   - Add a second step, reorder via drag
   - Verify cost summary updates with real labor totals
   - Create a second product, add the same existing step
   - Edit the step's time from Product B → verify Product A also reflects the change
   - Delete Product A → verify step still exists for Product B
   - Open Workshop tab → see all steps, tap into one
   - Set default labor rate in Settings → new steps pre-fill with that rate
