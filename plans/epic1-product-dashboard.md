# Epic 1: Product Dashboard

**Status:** Complete — pending CI verification and manual MacInCloud sign-off
**Branch:** `epic_1`

## Overview

Implement the core product and category management dashboard. Users can view all products in a list or grid, create/edit/delete products with metadata, manage categories, filter and search their dashboard, and move products between categories.

---

## Sub-Features Checklist

### SF-1 — CurrencyFormatter ✅
- [x] `@Observable final class CurrencyFormatter` with `.usd` / `.eur` currency enum
- [x] `format(_ value: Decimal) -> String` via `NumberFormatter` (converts `Decimal` as `NSDecimalNumber` — never casts to `Double`)
- [x] `EnvironmentKey` + `EnvironmentValues` extension for `\.currencyFormatter`
- [x] Injected once in `MakerMarginsApp.swift` via `.environment(\.currencyFormatter, ...)`

**Files:** `MakerMargins/Engine/CurrencyFormatter.swift`, `MakerMargins/MakerMarginsApp.swift`

---

### SF-2 — Category CRUD ✅
- [x] `SettingsView`: NavigationStack with currency Picker + nav rows for Categories and Platform Fee Profiles (stub)
- [x] `CategoryListView`: `@Query` sorted list, swipe-to-delete, row shows name + product count, toolbar Add button, tap-to-edit
- [x] `CategoryFormView`: sheet accepting `Category?` (nil = create), single name TextField, disabled Save on blank name
- [x] `ContentView`: Tab 3 wired to `SettingsView()`

**Files:** `MakerMargins/Views/Settings/SettingsView.swift`, `MakerMargins/Views/Categories/CategoryListView.swift`, `MakerMargins/Views/Categories/CategoryFormView.swift`, `MakerMargins/ContentView.swift`

---

### SF-3 — Product Form + Detail ✅
- [x] `ProductFormView`: accepts `Product?`, local `@State` fields (never bind TextField directly to model), `PhotosPicker` for image, `@Query` category picker, `Decimal` text fields via String intermediate, Save/Cancel toolbar
- [x] `ProductDetailView`: scrollable hub with header (image or placeholder, title, category badge, summary), `ProductCostSummaryCard`, labor stub, materials stub; Edit and Delete toolbar buttons
- [x] `ProductCostSummaryCard`: reusable card showing shipping cost (live) + all other cost lines as `$0.00` placeholder until Epic 2

**Files:** `MakerMargins/Views/Products/ProductFormView.swift`, `MakerMargins/Views/Products/ProductDetailView.swift`, `MakerMargins/Views/Products/ProductCostSummaryCard.swift`

---

### SF-4 — ProductListView (Dashboard) ✅
- [x] `@Query(sort: \Product.title)` + `@Query(sort: \Category.name)` for all data
- [x] In-memory `filteredProducts` computed property (name search + category filter via `persistentModelID` comparison)
- [x] Category filter chips: horizontal `ScrollView` of `Button` chips ("All" + one per category)
- [x] `.searchable(text: $searchText)` search bar
- [x] List mode: `List` with `NavigationLink(value:)` rows showing thumbnail + title + category; swipe-to-delete
- [x] Grid mode: `LazyVGrid` with adaptive 160pt columns; square image cell or photo placeholder
- [x] Toolbar: list/grid toggle button + Add button → `ProductFormView(product: nil)`
- [x] `ContentUnavailableView` empty state (no products vs. no results)
- [x] `.navigationDestination(for: Product.self)` → `ProductDetailView`
- [x] `ContentView`: Tab 1 wired to `ProductListView()`

**Files:** `MakerMargins/Views/Products/ProductListView.swift`, `MakerMargins/ContentView.swift`

---

### SF-5 — E2E Tests ✅
- [x] In-memory `ModelContainer` helper used by all tests
- [x] `createAndFetchProduct` — insert, save, fetch, assert count and title
- [x] `editProduct` — mutate title and shippingCost, save, assert changes persisted
- [x] `deleteProduct` — insert, delete, save, assert empty
- [x] `deleteProductCascadesToChildren` — insert Product + WorkStep + Material (bidirectional), delete product, save, assert all three gone
- [x] `createAndFetchCategory` — insert, save, fetch, assert count and name
- [x] `assignCategoryToProduct` — insert both, save, fetch product, assert `category?.name`
- [x] `deleteCategoryNullifiesProduct` — delete category, save, assert product survives with `category == nil`
- [x] `bufferPercentageStoredAsFraction` — simulate form save path (`"10"` ÷ 100), assert `materialBuffer == 0.1` and `laborBuffer == 0.05`
- [x] `currencyFormatterUSD` — assert result contains "$" and "19.99"
- [x] `currencyFormatterEUR` — assert result contains "€" or "EUR" and "19.99"
- [x] `currencyFormatterSwitchUpdatesOutput` — assert USD and EUR results differ
- [x] `currencyFormatterZero` — assert zero formats correctly with "$"

**Files:** `MakerMarginsTests/Epic1Tests.swift`

---

### SF-6 — Polish & Code Quality Fixes ✅
> Executed before SF-5. Fixes identified in the Epic 1 code and UX review.

#### UX Fixes

- [x] **Remove "Epic N" labels from user-facing views**
  - `ProductDetailView`: replaced with `"Add work steps to calculate labor costs"` / `"Add materials to calculate material costs"`
  - `SettingsView`: replaced with a `ContentUnavailableView` with proper descriptive copy
  - **Files:** `ProductDetailView.swift`, `SettingsView.swift`

- [x] **Buffer fields: accept percentage, store fraction**
  - On load: stored fraction × 100 for display (`0.10` → `"10"`)
  - On save: entered value ÷ 100 before storing (`"10"` → `Decimal("0.10")`)
  - Label hint changed from `"(fraction)"` to `"%"` trailing label
  - **Files:** `ProductFormView.swift`

- [x] **Add delete confirmation to list swipe-to-delete**
  - `@State private var productToDelete: Product?` + `.confirmationDialog` on the view
  - Swipe action sets `productToDelete`; dialog confirms before `modelContext.delete()`
  - **Files:** `ProductListView.swift`

- [x] **Move Delete action off the top navigation bar in `ProductDetailView`**
  - Replaced separate Edit + Delete toolbar items with a single `Menu` (`ellipsis.circle`) containing both actions
  - **Files:** `ProductDetailView.swift`

- [x] **Hide category chips when no categories exist**
  - Both list and grid layouts now guard with `if !categories.isEmpty`
  - **Files:** `ProductListView.swift`

#### Code Quality Fixes

- [x] **Cache `NumberFormatter` in `CurrencyFormatter`**
  - `NumberFormatter` now allocated once as a stored property; `currencyCode` updated via `didSet` on `selected`
  - **Files:** `CurrencyFormatter.swift`

- [x] **Extract shared `ProductThumbnailView`**
  - `ProductRowView` now uses `ProductThumbnailView(imageData:size:cornerRadius:)`
  - `ProductGridCell` keeps its own bespoke full-width layout with `UnevenRoundedRectangle` (different shape requirement)
  - **Files:** `ProductListView.swift`

- [x] **Remove unused `formatter` from `ProductFormView`**
  - `@Environment(\.currencyFormatter)` declaration removed
  - **Files:** `ProductFormView.swift`

- [x] **Fix `ContentUnavailableView` placement in `CategoryListView`**
  - Moved from inside a `List` row to `.overlay` on the `List`
  - **Files:** `CategoryListView.swift`

- [x] **Fix `.destructiveAction` toolbar placement**
  - Resolved as a side effect of the `Menu` consolidation fix above

- [x] **Replace `RoundedRectangle(cornerRadius: 0)` with `Rectangle()` in `ProductGridCell`**
  - **Files:** `ProductListView.swift`

- [x] **Fix `@Bindable` concern in `SettingsView`**
  - `$currencyFormatter.selected` used directly on an `@Environment` variable is not the Apple-recommended binding pattern for `@Observable` objects and may fail under Swift 6 strict concurrency
  - Use `@Bindable var formatter = currencyFormatter` inside the view body to derive a proper binding
  - **Files:** `SettingsView.swift`

**Files:** `MakerMargins/Engine/CurrencyFormatter.swift`, `MakerMargins/Views/Products/ProductFormView.swift`, `MakerMargins/Views/Products/ProductListView.swift`, `MakerMargins/Views/Products/ProductDetailView.swift`, `MakerMargins/Views/Categories/CategoryListView.swift`, `MakerMargins/Views/Settings/SettingsView.swift`

---

## Acceptance Criteria (from CLAUDE.md)

**Product CRUD**
- [ ] User can create a Product (title, summary, shippingCost, materialBuffer as %, laborBuffer as %, optional category)
- [ ] User can view a list of all Products on `ProductListView`
- [ ] User can tap a Product to open `ProductDetailView` (cost sections show $0.00 placeholders)
- [ ] User can edit a Product via `ProductFormView`
- [ ] User can delete a Product with confirmation from both the detail view and via swipe in the list; WorkSteps and Materials are cascade-deleted

**Category CRUD**
- [ ] User can create, edit, and delete Categories from `SettingsView → CategoryListView`
- [ ] User can assign a Category when creating/editing a Product
- [ ] Deleting a Category does NOT delete its Products (products become uncategorised)

**Currency Setting**
- [ ] `SettingsView` has a USD / EUR toggle
- [ ] `CurrencyFormatter` is implemented and used by all monetary display fields
- [ ] Switching currency re-renders all visible monetary values

**E2E Tests (Epic1Tests.swift)**
- [ ] Test: create a Product and fetch it back via SwiftData
- [ ] Test: create a Category, assign it to a Product, verify the relationship
- [ ] Test: delete a Category, verify the Product's category becomes nil
- [ ] Test: delete a Product, verify its WorkSteps and Materials are also deleted
- [ ] Test: CurrencyFormatter formats Decimal correctly for USD and EUR
- [ ] Test: buffer percentage input converts to correct fraction on save (e.g. user enters `10` → `materialBuffer == 0.10`)

---

## Key Technical Notes

- **No `id` on models** — use `persistentModelID` for identity comparisons (e.g. category filter)
- **`summary` not `description`** — avoids `NSObject.description` shadow
- **All monetary values use `Decimal`** — never `Double`. Format via `CurrencyFormatter` only
- **`@Observable` + environment** — currency switching re-renders automatically via SwiftUI observation
- **In-memory filter for category/search** — `#Predicate` on optional relationship traversal is fragile; computed property is simpler and correct for this scale
- **ProductFormView uses local `@State`** — initialised from model in `init()`, written back only on Save
- **Cascade delete** — set relationships bidirectionally before saving in tests (`step.product = p; p.workSteps.append(step)`)
- **Swift Testing** — `import Testing`, `@Test` macros, `#expect(...)` — no `XCTestCase`

---

## Verification

1. **CI:** push to `epic_1` → GitHub Actions runs XcodeGen → build → all Epic1Tests pass
2. **Manual (MacInCloud):**
   - Create a category in Settings → Categories
   - Create a product, assign the category
   - Toggle list/grid on the dashboard
   - Filter by category chip; search by name
   - Edit the product; change its category ("move" it)
   - Delete the category — product survives uncategorised
   - Delete the product — confirm dialog; product gone
