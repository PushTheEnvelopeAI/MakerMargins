# Epic 3.5: Item vs Product Cost Separation

**Status:** Planned
**Branch:** `epic_3.5` (from `epic_3`)

## Context

Epics 2-3 built the labor and material systems, but conflated item-level data with product-level data. Labor rate and "units per product" currently live on or are edited alongside the shared WorkStep/Material entities, but they are fundamentally **product-level concerns** — the same oak board costs $4/board-foot everywhere, but Product A might use 6 board-feet while Product B uses 2.

Epic 3.5 cleanly separates the two layers:

- **Item layer** (WorkStep / Material): Intrinsic properties of the item itself. A WorkStep knows how long it takes per unit. A Material knows its cost per unit. These values are universal — they don't change per product.
- **Product layer** (ProductWorkStep / ProductMaterial join models): How much of the item a specific product consumes, and at what rate. These values are per-product and editable in context.

This separation simplifies the creation forms (fewer fields, one clear goal), makes the shared-library concept more intuitive, and gives users per-product control where it matters.

---

## Design Sprint Summary

### Core Insight: "One Item, One Number"

Each item type produces exactly one key calculated value:

| Entity | User Inputs | Key Output |
|--------|------------|------------|
| WorkStep | Time to Complete Batch, Units per Batch | **Hours / Unit** |
| Material | Bulk Cost, Bulk Quantity | **Cost / Unit** |

Everything else (labor rate, units per product, total cost per product) is a **product-level concern** stored on the join model and displayed/edited when viewing the item in a product context.

### UX Flow: Labor Step

```
CREATE STEP (form)                    VIEW IN PRODUCT CONTEXT (detail)
┌─────────────────────────┐          ┌─────────────────────────────────┐
│ Image (optional)        │          │ [Item Info — read-only]         │
│ Title *                 │          │  Image, Title, Summary          │
│ Description             │          │  Recorded Time, Units/Batch     │
│ Time to Complete Batch  │          │  ➤ Hours / Unit (derived)       │
│   [Use Stopwatch]       │          │                                 │
│ Units per Batch         │          │ [Product Settings — editable]   │
│ Unit Name               │          │  Labor Rate    [default $25/hr] │
│                         │          │  Units / Product       [def: 1] │
│ ═══════════════════     │          │                                 │
│ ➤ Hours / Unit: 0.25   │          │ [Calculated — accent color]     │
│   (real-time preview)   │          │  Labor Hrs / Product: 0.25     │
└─────────────────────────┘          │  Labor Cost / Product: $6.25   │
                                     └─────────────────────────────────┘
```

### UX Flow: Material

```
CREATE MATERIAL (form)               VIEW IN PRODUCT CONTEXT (detail)
┌─────────────────────────┐          ┌─────────────────────────────────┐
│ Image (optional)        │          │ [Item Info — read-only]         │
│ Title *                 │          │  Image, Title, Summary, Link    │
│ Description             │          │  Bulk Cost, Bulk Qty, Unit Name │
│ Supplier Link           │          │  ➤ Cost / Unit (derived)        │
│ Bulk Cost               │          │                                 │
│ Bulk Quantity           │          │ [Product Settings — editable]   │
│ Unit Name               │          │  Units / Product       [def: 1] │
│                         │          │                                 │
│ ═══════════════════     │          │ [Calculated — accent color]     │
│ ➤ Cost / Unit: $2.50   │          │  Material Cost / Product: $2.50 │
│   (real-time preview)   │          └─────────────────────────────────┘
└─────────────────────────┘
```

### Library vs Product Context

When a step or material is viewed from the **library tab** (no product context), only the item info and key output (Hours/Unit or Cost/Unit) are shown. No labor rate, no units per product, no cost — those only exist in product context.

When viewed from a **product's detail view**, the full product-level section appears with editable fields and calculated costs.

---

## Schema Changes

### WorkStep (simplified)
- **Remove** `laborRate: Decimal` — moves to ProductWorkStep join model
- **Keep** `defaultUnitsPerProduct` — hidden from forms, used as default when creating join links (always 1)
- Remaining properties: `title`, `summary`, `image`, `recordedTime`, `batchUnitsCompleted`, `unitName`, `defaultUnitsPerProduct`, `productWorkSteps`

### ProductWorkStep (enhanced)
- **Add** `laborRate: Decimal` — per-product labor rate, defaults from `LaborRateManager.defaultRate` when creating a new association
- Existing: `product`, `workStep`, `sortOrder`, `unitsRequiredPerProduct`

### Material (no schema change)
- **Keep** `defaultUnitsPerProduct` — hidden from forms, used as default when creating join links (always 1)
- All properties unchanged

### ProductMaterial (no schema change)
- All properties unchanged — `unitsRequiredPerProduct` already lives here

### CostingEngine (modified)
- `stepLaborCost(link:)` — read `laborRate` from `link.laborRate` instead of `link.workStep.laborRate`
- `stepLaborCost(step:)` — **remove** (no labor rate on step anymore; library context shows Hours/Unit, not cost)
- Add `laborHoursPerProduct(link:)` = `unitTimeHours × unitsRequiredPerProduct`
- Raw-value overloads updated to match new signatures

---

## Sub-Features Checklist

### SF-1 — Schema Migration + CostingEngine Updates
**Goal:** Move `laborRate` to the join model and update all calculation functions. Foundation for everything else.

**Files to modify:**
- `Models/WorkStep.swift`
  - Remove `laborRate: Decimal` property
  - Remove `laborRate` from `init()` parameters
  - Update file header comment to reflect new purpose (item-level data only, no labor rate)
- `Models/ProductWorkStep.swift`
  - Add `var laborRate: Decimal = 0` property
  - Add `laborRate: Decimal = 0` to `init()` parameters
  - Update file header comment
- `Engine/CostingEngine.swift`
  - **Remove** `stepLaborCost(step:)` (no labor rate on WorkStep anymore)
  - **Update** `stepLaborCost(link:)` — use `link.laborRate` instead of `step.laborRate`
  - **Add** `laborHoursPerProduct(link:)` = `unitTimeHours(step:) × link.unitsRequiredPerProduct`
  - **Add** `laborHoursPerProduct(recordedTime:batchUnitsCompleted:unitsRequiredPerProduct:)` raw-value overload
  - **Update** `stepLaborCost(raw-value overload)` — signature stays the same, just used differently
  - **Keep** `unitTimeHours` functions unchanged (they're item-level)
  - **Keep** all material functions unchanged
  - **Keep** all product-level aggregate functions unchanged (they already use `link:` overloads)

**Files to update for compilation:**
- `Views/Labor/WorkStepDetailView.swift` — remove references to `step.laborRate`
- `Views/Labor/WorkStepFormView.swift` — remove laborRate field (detailed in SF-2)
- `Views/Labor/WorkStepListView.swift` — update row cost display to use link
- `Views/Workshop/WorkshopView.swift` — remove cost display from library rows (no labor rate available), show Hours/Unit instead
- `Views/Products/ProductListView.swift` — update `duplicateProduct()` to copy `laborRate` from ProductWorkStep joins
- Any test files referencing `step.laborRate` or `WorkStep(... laborRate:)`

---

### SF-2 — WorkStepFormView Simplification
**Goal:** Simplify the step creation/edit form to item-level fields only. Prominent Hours/Unit preview.

**Files to modify:**
- `Views/Labor/WorkStepFormView.swift`
  - **Remove** "Labor Rate" field and all associated @State / focus logic
  - **Remove** "Units per Product" field and all associated @State / focus logic
  - **Remove** step labor cost preview (no labor rate available in form)
  - **Keep** Image picker, Title, Summary, Time (h/m/s), Stopwatch button, Batch Units, Unit Name
  - **Add** prominent "Hours / Unit" calculated preview section:
    - Real-time calculation: `recordedTime / batchUnitsCompleted / 3600`
    - Displayed in accent color, large font, at bottom of form
    - Dynamic unit label (e.g. "Hours / board", "Hours / piece")
  - **Update** save logic: no longer sets `laborRate` on WorkStep
  - **Update** create logic: when creating with a product context, set `ProductWorkStep.laborRate` from `LaborRateManager.defaultRate`

---

### SF-3 — MaterialFormView Simplification
**Goal:** Simplify the material creation/edit form to item-level fields only. Prominent Cost/Unit preview.

**Files to modify:**
- `Views/Materials/MaterialFormView.swift`
  - **Remove** "Units per Product" field and all associated @State / focus logic
  - **Remove** material line cost preview ("Cost per Product" that depends on units per product)
  - **Keep** Image picker, Title, Summary, Link, Bulk Cost, Bulk Quantity, Unit Name
  - **Update** "Calculated Preview" section:
    - Show only "Cost / Unit" (prominent, accent color, large font)
    - Dynamic unit label (e.g. "Cost / oz", "Cost / board-foot")
    - Remove "Cost per Product" line (depends on product-level units per product)
  - **Update** save logic: no longer sets units per product on Material form
  - **Update** create logic: when creating with a product context, set `ProductMaterial.unitsRequiredPerProduct = 1`

---

### SF-4 — WorkStepDetailView Overhaul (Product Context Section)
**Goal:** Split detail view into item info (read-only) and product settings (editable). Show calculated costs only in product context.

**Files to modify:**
- `Views/Labor/WorkStepDetailView.swift`
  - **Restructure into two GroupBoxes:**
    1. **"Step Info" GroupBox** (always shown):
       - Image or placeholder
       - Summary text
       - Recorded Time (formatted)
       - Units per Batch + Unit Name
       - **Hours / Unit** (derived, accent color, prominent)
    2. **"Product Settings" GroupBox** (shown only when `product != nil`):
       - **Labor Rate** — editable TextField, decimal pad, defaults from LaborRateManager
         - Bound to `ProductWorkStep.laborRate` (find the link for this product)
         - Changes save immediately to the join model
       - **Units per Product** — editable TextField, decimal pad
         - Bound to `ProductWorkStep.unitsRequiredPerProduct`
         - Changes save immediately to the join model
       - **Labor Hours / Product** — derived, accent color
         - `= Hours/Unit × Units per Product`
       - **Labor Cost / Product** — derived, accent color, bold
         - `= Labor Hours/Product × Labor Rate`
  - **Keep** "Used By" GroupBox (always shown)
  - **Keep** toolbar: Edit (opens form), Delete
  - **Update** Stopwatch integration — no changes needed (writes to step.recordedTime)

---

### SF-5 — MaterialDetailView Overhaul (Product Context Section)
**Goal:** Mirror the WorkStepDetailView split for materials.

**Files to modify:**
- `Views/Materials/MaterialDetailView.swift`
  - **Restructure into two GroupBoxes:**
    1. **"Material Info" GroupBox** (always shown):
       - Image or placeholder
       - Summary text
       - Supplier link (tappable if non-empty)
       - Bulk Cost, Bulk Quantity, Unit Name
       - **Cost / Unit** (derived, accent color, prominent)
    2. **"Product Settings" GroupBox** (shown only when `product != nil`):
       - **Units per Product** — editable TextField, decimal pad
         - Bound to `ProductMaterial.unitsRequiredPerProduct`
         - Changes save immediately to the join model
       - **Material Cost / Product** — derived, accent color, bold
         - `= Cost/Unit × Units per Product`
  - **Keep** "Used By" GroupBox (always shown)
  - **Keep** toolbar: Edit (opens form), Delete

---

### SF-6 — List View Updates (WorkStepListView + MaterialListView + Library Views)
**Goal:** Update row displays and library views to reflect the new item-vs-product separation.

**Files to modify:**
- `Views/Labor/WorkStepListView.swift`
  - Row now shows: thumbnail + title + **Labor Cost / Product** (from join model's laborRate)
  - Cost uses `CostingEngine.stepLaborCost(link:)` which now reads `link.laborRate`
  - When creating a new step via "New Step" menu, ensure `ProductWorkStep.laborRate` is set from `LaborRateManager.defaultRate`
  - When adding existing step via picker, ensure `ProductWorkStep.laborRate` is set from `LaborRateManager.defaultRate`

- `Views/Workshop/WorkshopView.swift` (Labor library tab)
  - Row now shows: thumbnail + title + **Hours / Unit** (item-level only, no cost)
  - Replace `CostingEngine.stepLaborCost(step:)` with `CostingEngine.unitTimeHours(step:)` formatted display
  - "Used by" text remains unchanged

- `Views/Materials/MaterialListView.swift`
  - Row shows: thumbnail + title + **Material Cost / Product** (from join's unitsRequired × unitCost)
  - No functional change needed — `CostingEngine.materialLineCost(link:)` already uses join model

- `Views/Materials/MaterialsLibraryView.swift` (Materials library tab)
  - Row now shows: thumbnail + title + **Cost / Unit** (item-level only)
  - Replace `CostingEngine.materialLineCost(material:)` with `CostingEngine.materialUnitCost(material:)` formatted display
  - "Used by" text remains unchanged

---

### SF-7 — Product Duplication + Cost Summary Card
**Goal:** Ensure product duplication copies join-model fields (including new laborRate), and cost summary remains accurate.

**Files to modify:**
- `Views/Products/ProductListView.swift`
  - Update `duplicateProduct()` to copy `laborRate` from each `ProductWorkStep` join when duplicating
  - Existing: already copies `unitsRequiredPerProduct` and `sortOrder`

- `Views/Products/ProductCostSummaryCard.swift`
  - No functional change needed — already uses `CostingEngine.totalLaborCost(product:)` which traverses joins
  - Verify display is correct after schema change

---

### SF-8 — Test Updates
**Goal:** Update all tests for the new schema and add new tests for the item/product separation.

**Files to modify:**
- `MakerMarginsTests/Epic2Tests.swift`
  - Update all `WorkStep(... laborRate:)` calls — remove `laborRate` parameter
  - Update `ProductWorkStep` creation to include `laborRate`
  - Update `stepLaborCost` tests to use `link:` overload only
  - Add test: `unitTimeHours` calculation (item-level, unchanged)
  - Update `totalProductionCost` test for new schema

- `MakerMarginsTests/Epic3Tests.swift`
  - Update any tests that set `Material.defaultUnitsPerProduct` from forms
  - Verify `materialUnitCost` tests still pass (item-level, unchanged)
  - Verify `materialLineCost(link:)` tests still pass (join-level, unchanged)

- `MakerMarginsTests/Epic3_5Tests.swift` (new file)
  - Test: WorkStep creation without laborRate — verify property doesn't exist
  - Test: ProductWorkStep creation with laborRate — verify stored and retrievable
  - Test: `stepLaborCost(link:)` uses `link.laborRate`, not step-level rate
  - Test: `laborHoursPerProduct(link:)` calculation
  - Test: changing `ProductWorkStep.laborRate` on one product doesn't affect another product using the same step
  - Test: changing `ProductWorkStep.unitsRequiredPerProduct` on one product doesn't affect another
  - Test: product duplication copies `laborRate` from join models
  - Test: library-context step shows Hours/Unit (no cost)
  - Test: `materialUnitCost` is purely item-level (no product dependency)

---

## Key Design Decisions

- **Labor rate on join model, not step:** A woodworker might value their own time at $25/hr but charge $35/hr for a commissioned piece. Same step, different rate per product. This is the core motivating change.
- **"One item, one number" principle:** WorkStep → Hours/Unit. Material → Cost/Unit. Everything else is product context. This simplifies the mental model for users.
- **Inline editing for product-level fields:** Labor rate and units per product are editable directly in the detail view (not a separate form), because they're quick overrides rather than complex inputs.
- **Library views show item-level metrics only:** The Labor tab shows Hours/Unit, not cost. The Materials tab shows Cost/Unit. Cost only appears in product context where a rate/quantity is defined.
- **`defaultUnitsPerProduct` kept on models:** Retained as a hidden default (always 1) for pre-filling join models. Not exposed in forms. Could be removed in a future cleanup if never needed.
- **No change to Material schema:** Material's cost structure (bulkCost / bulkQuantity → Cost/Unit) is already purely item-level. Only the form and detail view UX change. ProductMaterial already has `unitsRequiredPerProduct`.
- **Immediate save for product-level fields:** Unlike the item form (which uses write-back-on-save), product-level fields in the detail view save to the join model on edit (onChange or onSubmit). This gives instant feedback in the cost summary card.

---

## Key Technical Notes

- **SwiftData migration:** Removing `laborRate` from WorkStep and adding it to ProductWorkStep is a lightweight migration. SwiftData handles column additions/removals automatically. No manual migration plan needed since this is pre-release.
- **LaborRateManager default:** When creating a `ProductWorkStep`, read `LaborRateManager.defaultRate` to pre-fill `laborRate`. This requires the environment value to be accessible at creation time — pass it through from the view.
- **CostingEngine signature cleanup:** The `stepLaborCost(step:)` overload becomes meaningless without a labor rate. Remove it entirely. Library views that showed per-step cost now show `unitTimeHours` instead.
- **Raw-value overloads for detail view:** The product-level section in the detail view needs real-time previews as the user edits labor rate / units per product. Add raw-value overloads for `laborHoursPerProduct` and `stepLaborCost` that accept primitives.
- **Finding the correct ProductWorkStep link:** In the detail view, find the join link via `step.productWorkSteps.first { $0.product == product }`. Guard against nil.
- **Stopwatch unaffected:** The stopwatch writes to `step.recordedTime` which remains on WorkStep. No changes needed.

---

## Phase Sequencing

```
SF-1 (Schema + Engine)                 ← foundation, must be first
  │
  ├── SF-2 (WorkStepFormView)          ← needs updated WorkStep model
  │     │
  │     └── SF-4 (WorkStepDetailView)  ← needs simplified form + product context section
  │
  ├── SF-3 (MaterialFormView)          ← needs understanding of separation pattern
  │     │
  │     └── SF-5 (MaterialDetailView)  ← needs simplified form + product context section
  │
  ├── SF-6 (List + Library views)      ← needs updated CostingEngine
  │
  ├── SF-7 (Duplication + Cost Card)   ← needs updated join model
  │
  └── SF-8 (Tests)                     ← write incrementally, finalize at end
```

SF-2 and SF-3 can be done in parallel.
SF-4 and SF-5 can be done in parallel (after their respective form SFs).
SF-6 and SF-7 can be done in parallel (after SF-1).
SF-8 is incremental throughout.

---

## CLAUDE.md Updates Required

After Epic 3.5 is complete, update the following CLAUDE.md sections:
- **Core Schema:** Move `laborRate` from WorkStep table to ProductWorkStep table
- **Calculation Logic:** Update formulas to show `laborRate` comes from join model
- **Key Decisions:** Add note about item-vs-product separation rationale
- **WorkStep form fields** in navigation/view descriptions
- **Epic roadmap table:** Add Epic 3.5 row

---

## Verification

1. **CI:** Push to `epic_3.5` → GitHub Actions: XcodeGen → build → all Epic1-3 tests (updated) + Epic3.5Tests pass
2. **Manual (MacInCloud):**
   - Create a new WorkStep from product detail → form shows only: image, title, description, time, batch units, unit name
   - Verify Hours/Unit calculates in real-time as time and batch fields are filled
   - Tap the created step → see item info + product settings (labor rate pre-filled from settings, units per product = 1)
   - Edit labor rate in product settings → verify Labor Cost/Product updates immediately
   - Edit units per product → verify Labor Hours/Product and Labor Cost/Product update
   - Add the same step to a second product → change labor rate on Product B → verify Product A is unaffected
   - Open Labor tab → verify rows show Hours/Unit (not cost)
   - Create standalone step from Labor tab → verify no product settings section in detail
   - Create a Material from product detail → form shows only: image, title, description, link, bulk cost, bulk quantity, unit name
   - Verify Cost/Unit calculates in real-time
   - Tap material → see item info + product settings (units per product = 1)
   - Edit units per product → verify Material Cost/Product updates
   - Open Materials tab → verify rows show Cost/Unit (not line cost)
   - Duplicate a product → verify labor rates are copied per-step on the duplicate
   - Verify ProductCostSummaryCard totals are correct throughout
   - Use stopwatch → verify time saves correctly to step, Hours/Unit updates
