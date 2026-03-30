# Epic 3: Material Ledger & Costing

**Status:** Planned
**Branch:** `epic_3` (from `main`)

## Context

Epic 2 delivered the labor engine with shared/reusable WorkSteps linked to Products via a `ProductWorkStep` join model. Epic 3 mirrors this architecture for Materials — transforming them from product-owned entities into shared library items that can be reused across products. Users need to define materials with purchase costs, see per-unit and per-product costs calculated automatically, manage a shared material library, and see accurate production costs with per-section buffers.

**Key changes from current state:**
- Material becomes a shared entity (many-to-many via `ProductMaterial` join model)
- CostingEngine gets full material calculation functions
- Buffer formula changes from combined multiplier to per-section application
- Buffers become editable inline in each section of ProductDetailView
- Materials tab (Tab 3) becomes a functional shared library

---

## Schema Changes

### ProductMaterial (new join model)
| Property | Type | Notes |
|----------|------|-------|
| product | Product? | Many-to-one |
| material | Material? | Many-to-one |
| sortOrder | Int | Per-product display order. Default: 0 |

Cascade rules mirror ProductWorkStep:
- Deleting a Product cascade-deletes its `ProductMaterial` entries (associations only — Materials survive in library)
- Deleting a Material cascade-deletes its `ProductMaterial` entries (Products survive)

### Material (modified — shared entity)
- **Remove** `product: Product?`
- **Add** `@Relationship(deleteRule: .cascade) var productMaterials: [ProductMaterial] = []`
- **Add** `var image: Data?` (optional image blob)
- **Add** `var link: String` (supplier URL, default empty string)

### Product (modified)
- **Replace** `@Relationship(deleteRule: .cascade) var materials: [Material] = []` with `@Relationship(deleteRule: .cascade) var productMaterials: [ProductMaterial] = []`

### CostingEngine (modified — buffer formula change)
- **Old:** `(labor + material + shipping) × (1 + materialBuffer + laborBuffer)`
- **New:** `labor × (1 + laborBuffer) + material × (1 + materialBuffer) + shipping`
- Shipping is never buffered. Each buffer applies only to its own cost category.

---

## Sub-Features Checklist

### SF-1 — Schema Changes + CostingEngine Material Functions
**Goal:** Lay the data and calculation foundation. Everything downstream depends on this.

**Files to create:**
- `Models/ProductMaterial.swift` — join model (mirrors `ProductWorkStep.swift`: `product`, `material`, `sortOrder`)

**Files to modify:**
- `Models/Material.swift`
  - Remove `product: Product?`
  - Add `@Relationship(deleteRule: .cascade) var productMaterials: [ProductMaterial] = []`
  - Add `var image: Data?` (default nil)
  - Add `var link: String` (default `""`)
  - Update `init()` — remove `product` parameter, add `image` and `link`
- `Models/Product.swift`
  - Replace `materials: [Material]` with `productMaterials: [ProductMaterial]` (cascade delete)
- `MakerMarginsApp.swift`
  - Add `ProductMaterial.self` to Schema array
- `Engine/CostingEngine.swift`
  - Implement `materialUnitCost(material:)` + raw-value overload (`bulkCost / bulkQuantity`, zero guard)
  - Implement `materialLineCost(material:)` + raw-value overload (`unitCost × unitsRequiredPerProduct`)
  - Implement `totalMaterialCost(product:)` — traverse `product.productMaterials` → `material`, sum `materialLineCost`
  - Add `totalLaborCostBuffered(product:)` — `labor × (1 + laborBuffer)`
  - Add `totalMaterialCostBuffered(product:)` — `material × (1 + materialBuffer)`
  - **Change** `totalProductionCost(product:)` to per-section buffer formula
- `Views/Products/ProductListView.swift`
  - Update `duplicateProduct()` — materials are now re-linked (shared) via `ProductMaterial` associations, not deep-copied
  - Update delete confirmation message (materials now survive product deletion)
- `MakerMarginsTests/Epic1Tests.swift`
  - Update references from `product.materials` to `product.productMaterials`
  - Add `ProductMaterial.self` to `makeContainer()` Schema array
  - Update cascade delete test expectations (materials are shared, not cascade-deleted with product)
  - Update duplication test (materials are re-linked, not deep-copied)
- `MakerMarginsTests/Epic2Tests.swift`
  - Add `ProductMaterial.self` to `makeContainer()` Schema array
  - Update `totalProductionCost` test for new per-section buffer formula

---

### SF-2 — MaterialFormView (Create & Edit)
**Goal:** Full create/edit form mirroring WorkStepFormView.

**Files to modify:**
- `Views/Materials/MaterialFormView.swift` (replace stub)

**Structure:**
- `init(material: Material?, product: Product?)` — nil material = create; nil product = standalone library material
- Local `@State` for all fields, write-back-on-save pattern
- `@FocusState` with clear-on-focus / restore-on-blur for numeric fields

**Sections:**
1. **Image** — PhotosPicker (same pattern as WorkStepFormView)
2. **Details** — Title (required, disables Save when empty), Summary (multiline), Link (URL keyboard type, optional)
3. **Purchase Info** — Bulk Cost (currency prefix + decimal pad), Bulk Quantity (decimal pad, min 1), Unit Name (text, default "unit"), Units per Product (decimal pad)
   - Dynamic labels: e.g. "Ounces per Product" updates when unitName changes
   - Section footer explaining fields
4. **Calculated Preview** (real-time, accent color) — Cost per unit, Cost per product

**Save logic:**
- Create: insert Material + create ProductMaterial link (with sortOrder = count) if product is non-nil
- Edit: update Material properties in-place (propagates to all products)

---

### SF-3 — MaterialThumbnailView + MaterialListView + ProductDetailView Integration
**Goal:** Inline material list in ProductDetailView with add new/existing, reorder, remove, and buffer display.

**Files to modify:**
- `Theme/ViewModifiers.swift`
  - Add `MaterialThumbnailView` — mirrors `WorkStepThumbnailView`, uses `shippingbox` SF Symbol for placeholder

- `Views/Materials/MaterialListView.swift` (replace stub)
  - Mirror `WorkStepListView` structure:
    - `let product: Product`
    - `@Query(sort: \Material.title) private var allMaterials: [Material]`
    - Computed: `sortedLinks`, `linkedMaterialIDs`, `availableMaterials`
    - GroupBox label: "Materials" + Reorder toggle + Plus menu ("New Material", "Add Existing Material")
    - Empty state: "Add materials to calculate material costs"
    - Material rows: `MaterialThumbnailView` + title + `materialLineCost` + NavigationLink chevron
    - Context menu: "Remove from Product" (removes association, not material)
    - Reorder mode: up/down arrow buttons
    - Existing material picker sheet: checkmark toggle, batch add, usage count display
    - Total footer: "Total Materials" + accent-colored sum
    - **Buffer section** (below total):
      - "Material Cost Buffer" label + editable TextField (display as whole %, store as fraction)
      - "Total after buffer" row showing `CostingEngine.totalMaterialCostBuffered(product:)` in accent
    - Remove confirmation dialog

- `Views/Products/ProductDetailView.swift`
  - Replace `materialsSection` stub GroupBox with `MaterialListView(product: product)`
  - Add `.navigationDestination(for: Material.self)` → `MaterialDetailView`

---

### SF-4 — Labor Section Buffer Display
**Goal:** Add inline buffer % editing to WorkStepListView, matching the material section pattern from SF-3.

**Files to modify:**
- `Views/Labor/WorkStepListView.swift`
  - After `totalFooter`, add buffer section:
    - "Labor Cost Buffer" label + editable TextField (whole % ↔ fraction)
    - "Total after buffer" showing `CostingEngine.totalLaborCostBuffered(product:)` in accent
  - Matches the material buffer display exactly for visual consistency

---

### SF-5 — MaterialDetailView (Scrollable Hub)
**Goal:** Full detail view mirroring WorkStepDetailView.

**Files to modify:**
- `Views/Materials/MaterialDetailView.swift` (replace stub)

**Structure:**
- `let material: Material`, `var product: Product?`
- **Header:** image or PlaceholderImageView, summary text, tappable link (if non-empty)
- **Purchase GroupBox:** Bulk Cost, Bulk Quantity, Unit Name, Units per Product
- **Cost GroupBox:** Cost per Unit (derived, accent), Cost per Product (derived, accent, bold)
- **Used By GroupBox:** linked products with thumbnails (from `material.productMaterials.compactMap(\.product)`)
- **Toolbar:** Edit (pencil) → MaterialFormView sheet; Delete (ellipsis menu) → confirmation with shared-material warning

---

### SF-6 — MaterialsLibraryView (Tab 3)
**Goal:** Full library view mirroring WorkshopView.

**Files to modify:**
- `Views/Materials/MaterialsLibraryView.swift` (replace stub)

**Structure:**
- `@Query(sort: \Material.title) private var allMaterials: [Material]`
- Searchable by title
- Each row: `MaterialThumbnailView` + title + "Used by X + N others" + `materialLineCost`
- Toolbar "+" → MaterialFormView (nil material, nil product)
- `.navigationDestination(for: Material.self)` → MaterialDetailView
- Empty state: "No Materials" + helper text
- Search-no-results state

---

### SF-7 — Cost Summary Updates (ProductCostSummaryCard)
**Goal:** Live material costs and updated production total in the cost summary card.

**Files to modify:**
- `Views/Products/ProductCostSummaryCard.swift`
  - Replace materials stub with live `CostingEngine.totalMaterialCost(product:)`
  - Remove "Available in Epic 3" note
  - Update layout to show:
    - Labor (raw) + buffer % note
    - Materials (raw) + buffer % note
    - Shipping
    - Total Production Cost (using new per-section buffer formula)
  - Total uses `CostingEngine.totalProductionCost(product:)` which now applies per-section buffers

---

### SF-8 — E2E Tests
**Goal:** Comprehensive test coverage for Epic 3.

**Files to modify:**
- `MakerMarginsTests/Epic3Tests.swift` (replace stub)

**Tests:**
1. Create Material with all fields — persist, fetch, verify all properties including image and link
2. Create ProductMaterial association — verify sortOrder
3. Shared material across two products — edit propagates to both
4. Reorder materials — verify sortOrder updates
5. Delete product preserves shared Material — verify Material survives, associations removed
6. Delete Material cascades to ProductMaterial associations — verify associations gone, product survives
7. CostingEngine.materialUnitCost — known values (e.g. $20 / 10 = $2)
8. CostingEngine.materialUnitCost — zero guard (bulkQuantity = 0 → returns 0)
9. CostingEngine.materialLineCost — known values
10. CostingEngine.totalMaterialCost — sum across multiple materials
11. CostingEngine.totalProductionCost — verify per-section buffer formula
12. Product duplication re-links shared materials — verify new ProductMaterial associations, same Material entities

---

## Key Design Decisions

- **Shared materials (many-to-many):** Materials are reusable across products via `ProductMaterial` join model. Edit once, updates everywhere. Materials tab serves as the library. Mirrors the WorkStep/ProductWorkStep pattern exactly.
- **Per-section buffer formula:** Each buffer applies only to its own cost category. `labor × (1 + laborBuffer) + material × (1 + materialBuffer) + shipping`. Shipping is never buffered. This is a breaking change from Epic 2's combined multiplier — Epic2 tests updated accordingly.
- **Duplication re-links, not deep-copies:** Consistent with shared library concept. Duplicated product gets new `ProductMaterial` associations pointing to the same Material entities.
- **`link` as String, not URL:** SwiftData-friendly. Validated/converted to URL only at display time. Empty string = no link.
- **Buffer editing inline in sections:** Primary editing surface for buffers moves from ProductFormView to inline TextFields in WorkStepListView and MaterialListView. ProductFormView retains its buffer fields for initial setup.
- **`MaterialThumbnailView` uses `shippingbox` icon:** Distinct from WorkStepThumbnailView's `wrench.and.screwdriver`, matches the Materials tab icon.

---

## Key Technical Notes

- **`Product?` on MaterialFormView** — nil creates standalone library material. Materials tab uses this.
- **`Product?` on MaterialDetailView** — optional edit context. Falls back to first linked product.
- **Schema migration safety:** Adding `ProductMaterial` and changing Material's relationships is safe because no user data exists for materials yet (all stubs). SwiftData handles the lightweight migration.
- **Buffer TextField pattern:** Display as whole number ("10" = 10%), store as fraction (0.10). Use `@FocusState` clear-on-focus pattern from WorkStepFormView.
- **`bulkQuantity` zero guard:** `materialUnitCost` must return 0 when `bulkQuantity` is 0, same pattern as `unitTimeHours`.

---

## Phase Sequencing

```
SF-1 (Schema + Engine)           ← foundation, everything depends on this
  │
  ├── SF-2 (MaterialFormView)    ← needs model + CostingEngine raw overloads
  │     │
  │     ├── SF-3 (MaterialListView + ProductDetailView)  ← needs form for "New Material" sheet
  │     │     │
  │     │     ├── SF-4 (Labor buffer display)  ← pattern established in SF-3
  │     │     │
  │     │     └── SF-5 (MaterialDetailView)    ← needs list for navigation source
  │     │           │
  │     │           └── SF-6 (MaterialsLibraryView)  ← needs detail for navigation dest
  │     │
  │     └── SF-7 (Cost Summary)  ← can parallel with SF-3 after SF-1
  │
  └── SF-8 (Tests)               ← write incrementally, finalize at end
```

---

## Verification

1. **CI:** Push to `epic_3` → GitHub Actions: XcodeGen → build → all Epic1Tests + Epic2Tests (updated) + Epic3Tests pass
2. **Manual (MacInCloud):**
   - Create a Material from a product's detail view — fill all fields, verify real-time cost preview
   - Create a second material, reorder via arrows
   - Verify material cost and total production cost update in cost summary card
   - Edit material buffer % inline — verify "total after buffer" updates live
   - Edit labor buffer % inline — verify same
   - Create a second product, add the same existing material
   - Edit material's bulk cost from Product B → verify Product A reflects the change
   - Delete Product A → verify material still exists for Product B
   - Open Materials tab → see all materials, tap into detail, verify "Used By"
   - Create standalone material from Materials tab
   - Duplicate a product → verify materials are re-linked (shared), not deep-copied
   - Verify ProductCostSummaryCard shows correct per-section buffered totals
