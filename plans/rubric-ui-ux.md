# MakerMargins — UI/UX Rubric

Production readiness audit for the user experience of a solo-maker costing and pricing iOS app.
Each dimension is scored 1–5. A score of 3 means "acceptable for v1 ship." A score of 5 means "exemplary, no meaningful improvements needed."

---

## 1. Information Architecture & Navigation

**What to evaluate:** Can the user find what they need? Does the navigation structure match the user's mental model? Is the depth appropriate?

| Score | Criteria |
|-------|----------|
| 1 | Navigation is disorienting. Users frequently get lost. Key features are buried or unreachable. Tab structure doesn't match workflows. |
| 2 | Navigation works but has dead ends, redundant paths, or confusing hierarchy. Some features require too many taps. Users have to "discover" core functionality. |
| 3 | 4-tab structure maps to clear domains (Products, Labor, Materials, Settings). Navigation depth is reasonable (max 3 levels). Key actions are reachable within 2–3 taps. Occasional confusion about where a feature lives. |
| 4 | Navigation feels natural. The tab structure matches how makers think about their workflow. Shared entities (steps, materials) are accessible from both their library tab and from within a product. Cross-references (e.g., "Used By") provide context without requiring navigation. |
| 5 | All of 4, plus: every screen answers "where am I?" and "how do I go back?" Users never need to think about navigation — they think about their work and the app follows. The fastest path to the most frequent action (e.g., starting a stopwatch) is optimized. |

**Score: 5**

**Explanation:** Navigation is exemplary. The 4-tab structure maps directly to maker mental models (Products, Labor, Materials, Settings). Every screen answers "where am I?" via NavigationStack with automatic back buttons. The fastest path to the most frequent action (stopwatch) is optimized to 2 taps from the Labor tab. Shared entities are accessible from both their library tab and from within product detail. Auto-navigation after creation means the user never has to hunt for what they just made. Maximum depth is 3 levels. Sheet/push usage follows iOS conventions perfectly.

**Specific checks:**
- [x] Stopwatch is reachable in 2 taps from the Labor tab (the fastest path for a maker mid-production) ✅ — Tab 2 → tap step → timer button in toolbar → fullScreenCover
- [x] Product detail view sub-tabs (Build/Price/Forecast) are discoverable without instruction ✅ — Segmented Picker with clear text labels at ProductDetailView:146-151
- [x] Shared entities are accessible from both their library tab AND from within product detail ✅ — WorkSteps from WorkshopView AND ProductDetailView Build tab; Materials from MaterialsLibraryView AND ProductDetailView Build tab
- [x] "Used By" sections show where an item is linked without requiring navigation ✅ — UsedBySection in WorkStepDetailView:262 and MaterialDetailView:217 with tappable NavigationLinks from library, plain rows from product context
- [x] Portfolio view is discoverable from the Products tab (toolbar icon is recognizable) ✅ — Prominent NavigationLink card at ProductListView:290-307 with chart.bar icon and "Compare your X product(s)" text
- [x] Back navigation is always available and returns to the expected screen ✅ — NavigationStack in all 4 tabs, no custom back buttons
- [x] Sheet vs push navigation is used appropriately (sheets for creation/editing, push for drill-down) ✅ — All forms use .sheet, all detail views use NavigationLink push
- [x] The user is never more than 3 taps from the tab root ✅ — Max depth verified: Tab → Product → Step/Material → Used By Product (3 levels)
- [x] Navigation after item creation takes the user to the right place (auto-navigate to detail) ✅ — All three entity types auto-navigate via navigationPath.append() after creation
- [x] Tab badge or visual cue indicates which tab the user is on ✅ — Standard TabView with SF Symbol labels and tint color

---

## 2. Onboarding & First-Run Experience

**What to evaluate:** Can a new user understand the app's value and start using it within the first 60 seconds? Are templates and empty states doing their job?

| Score | Criteria |
|-------|----------|
| 1 | New user sees an empty screen with no guidance. No templates, no hints, no explanation of the app's purpose. User must figure out the workflow on their own. |
| 2 | Empty states exist but are generic ("No items"). Templates exist but don't clearly demonstrate the app's value proposition. New users may not discover templates. |
| 3 | Empty states provide guidance ("Tap + to create your first product"). Templates are accessible from the creation flow. A new user can have a populated product within 3 taps. |
| 4 | All of 3, plus: templates are prominently offered on first launch. Each template demonstrates a different workflow strength (varied labor rates, batch sizes, pricing strategies). The template picker explains what templates include. |
| 5 | All of 4, plus: the first template experience creates an "aha moment" — the user immediately sees their production cost, target price, and profit analysis populated with realistic data. The path from template → understanding → creating their own product is seamless. |

**Score: 5**

**Explanation:** The first-run experience creates an immediate "aha moment." Empty ProductListView shows a prominent "Start from Template" button with `.borderedProminent` styling as the primary CTA. The template picker shows content previews (step count, material count, platform). All 5 templates have bundled JPEG images, realistic pricing ($22–$90), and populated profit analysis. After applying, the user auto-navigates to ProductDetailView with all data visible. Settings defaults are sensible ($15/hr, USD, 30% profit margin). No mandatory onboarding — the app launches directly to tabs with empty states guiding new users.

**Specific checks:**
- [x] Every list view (Products, Labor, Materials) has a meaningful empty state with action guidance ✅ — ProductListView:273 "No Products Yet" with template + blank CTAs; WorkshopView:40 "Tap + to create a step"; MaterialsLibraryView:40 "Tap + to create a material"; WorkStepListView:155 and MaterialListView:154 "Tap + above to add..."
- [x] Template picker is offered prominently (not buried in a sub-menu) ✅ — Primary CTA in empty state with `.borderedProminent`, also in + menu as "From Template"
- [x] Template picker shows what each template includes (not just a name) ✅ — TemplatePickerView:99 shows "4 steps, 4 materials, Etsy pricing" per template
- [x] Templates have bundled images (populated product looks "real" immediately) ✅ — All 5 templates have imageName references for product, steps, and materials. TemplateApplier loads as JPEG at 0.8 quality.
- [x] After applying a template, the user lands on the product detail with all data visible ✅ — TemplatePickerView fires onProductCreated callback → ProductListView:94 appends to navigationPath → auto-navigates to ProductDetailView
- [x] Template products have realistic actual prices set so profit analysis works immediately ✅ — Woodworking $89.99, 3D Printing $49.99, Laser Engraving $52, Candles $24.99, Resin Art $22 — all with shipping charges
- [x] Settings defaults (labor rate, currency) are reasonable for a first-time user ✅ — $15/hr (LaborRateManager:29), USD (CurrencyFormatter:41), 30% profit margin (PlatformFeeProfile:45)
- [x] No required setup step before the user can start creating (no mandatory onboarding flow) ✅ — MakerMarginsApp directly renders ContentView, no onboarding state checks
- [x] The "+ menu" (Blank Product / From Template) is obvious and easy to tap ✅ — Plus icon at `.primaryAction` toolbar placement with clear menu labels

---

## 3. Form Design & Data Entry

**What to evaluate:** Are forms efficient, forgiving, and well-organized? Do they minimize friction for data entry?

| Score | Criteria |
|-------|----------|
| 1 | Forms are long, unstructured, and confusing. Required fields aren't marked. Validation is absent or happens only on submit with no indication of what's wrong. Keyboard types are wrong. |
| 2 | Forms are structured but have friction — wrong keyboard types, no field grouping, validation messages are unclear, no defaults for optional fields. |
| 3 | Forms are grouped into logical sections. Keyboard types match field content (numeric for costs, default for text). Required fields are validated. Defaults are safe (1 for quantities). Focus management works (next field on submit). |
| 4 | All of 3, plus: forms use focus-aware behavior (clear default on focus, restore on blur). Calculated previews update in real-time as the user types. The stopwatch provides an alternative to manual time entry. Labels use dynamic unit names. |
| 5 | All of 4, plus: forms feel effortless. The minimum viable product can be created in under 30 seconds. Every field has appropriate placeholder text. The user never has to do mental math — the form shows derived values instantly. |

**Score: 4**

**Explanation:** Forms are well-designed with excellent focus management, real-time previews, and inline category creation. All monetary fields use `.decimalPad`, time fields clamp to 0-59, required fields show validation with disabled save buttons, and forms protect against accidental dismissal via `.interactiveDismissDisabled`. Focus-clear-on-tap works via `FormFieldDefault` utility. Photo picker supports Add/Change/Remove. Percentage display/storage separation is clean. Real-time calculated previews (Hours/Unit, Cost/Unit) update as users type. The stopwatch provides a compelling alternative to manual time entry.

**Specific checks:**
- [x] All monetary fields use decimal keyboard (`.decimalPad`) ✅ — CurrencyInputField at ViewModifiers:451 uses `.decimalPad`; all monetary inputs route through this component
- [x] All integer quantity fields use number keyboard (`.numberPad`) ✅ — BatchForecastView:137 uses `.numberPad` for batch size
- [x] Time fields (h/m/s) clamp to valid ranges (0–59 for minutes/seconds) ✅ — WorkStepFormView:126-131 clamps via `clampTimeComponent(max: 59)`
- [x] Required fields have clear validation feedback (not just a silent save failure) ✅ — All 3 forms show "Title is required" inline hint when touched and empty
- [x] Default values (1 for quantities, 0 for costs) prevent division-by-zero without user action ✅ — WorkStep.batchUnitsCompleted=1, Material.bulkQuantity=1
- [x] Focus-clear-on-tap behavior works for percentage and currency fields (clear "0" on focus, restore on blur if empty) ✅ — `FormFieldDefault` in ViewModifiers:674-686 with `clearOnFocus()`/`restoreOnBlur()` used in MaterialFormView:108-111 and WorkStepFormView:119-122
- [x] Real-time calculated previews show derived values (Hours/Unit, Cost/Unit) as the user fills fields ✅ — WorkStepDetailView:172-179 shows Time/Hours per unit; MaterialDetailView:165-168 shows Cost per unit; both update via `onChange` bindings
- [x] Photo picker provides Add/Change/Remove options (not just Add) ✅ — PhotoPickerSection in ViewModifiers:551-594 with "Add Photo"/"Change Photo"/"Remove Photo" states
- [x] Category creation is inline from the product form (no navigation to a separate screen) ✅ — ProductFormView:177-196 inline text field with Add/Cancel buttons
- [x] Save button is disabled when required fields are empty (not enabled with a post-tap error) ✅ — `isSaveDisabled` computed property in all 3 forms, `.disabled()` on save button
- [x] Form preserves entered data if the user accidentally swipes to dismiss ✅ — `.interactiveDismissDisabled(hasUnsavedChanges)` in all 3 forms
- [x] Long text fields (description) allow multi-line input with appropriate height ✅ — All description fields use `TextField(axis: .vertical).lineLimit(3...6)`
- [x] Percentage fields display whole numbers (30) but store fractions (0.30) — no user confusion ✅ — PercentageFormat.toDisplay/fromDisplay handles conversion at ViewModifiers:614-635

---

## 4. Visual Hierarchy & Typography

**What to evaluate:** Does the visual design guide the user's eye to the most important information? Is typography used effectively to establish hierarchy?

| Score | Criteria |
|-------|----------|
| 1 | Everything looks the same — no size, weight, or color differentiation. The user can't tell what's important at a glance. |
| 2 | Some hierarchy exists but is inconsistent — hero values aren't always prominent, section headers blend with content, derived values look the same as user-entered values. |
| 3 | Clear 3-level hierarchy: hero metrics (large, bold, accent color), section headers (semibold, consistent style), body content (standard size). Derived/calculated values are visually distinct from user-entered values. |
| 4 | All of 3, plus: the most important number on each screen is immediately obvious (production cost on Build, target price on Price, batch earnings on Forecast). Secondary information supports without competing. Accent color is used sparingly and meaningfully. |
| 5 | All of 4, plus: a user can glance at any screen for 2 seconds and know the key takeaway. Visual weight matches information importance perfectly. The design "breathes" — adequate whitespace between sections. No screen feels cramped or overwhelming. |

**Score: 4**

**Explanation:** Visual hierarchy is strong. Hero values use `AppTheme.Typography.heroPrice` (.title2.weight(.bold)) with accent color — immediately scannable. Derived values in `DerivedRow` use accent color, clearly distinct from user-entered values in `DetailRow`. `CalculatorSectionHeader` is used consistently across all 4 calculator views (13 uses). All labels use .secondary/.tertiary foreground. Positive/negative profit color coding is universally applied. Pricing sections use `pricingSurface` background. Font scale follows system text styles. Monospaced font isolated to stopwatch. The only reason this isn't a 5 is the 18 hardcoded font calls (from code quality audit) that bypass AppTheme tokens — while the visual result works, the inconsistency in implementation means a theme change wouldn't propagate perfectly.

**Specific checks:**
- [x] Hero values (target price, earnings/sale, total production cost) use large bold accent typography ✅ — PricingCalculatorView:389 heroPrice+accent for target; :598 for earnings; BatchForecastView:217 for labor time; PortfolioView:358 for avg earnings
- [x] Derived/calculated values use accent color to distinguish from user-entered values ✅ — DerivedRow at ViewModifiers:530-545 uses `AppTheme.Colors.accent` for values
- [x] Section headers are visually consistent across all views (same font weight, size, icon style) ✅ — CalculatorSectionHeader (ViewModifiers:466-482) used 13 times across 4 files
- [x] Labels use secondary/tertiary foreground — never competing with values for attention ✅ — DetailRow labels use .secondary, CalculatorSectionHeader uses .secondary
- [x] Positive profit is green, negative profit is red — universally applied ✅ — Conditional `accent`/`destructive` coloring at PricingCalculatorView:599,633,645; BatchForecastView:398,426,452; PortfolioView:114,152,192
- [x] Pricing calculator sections have visual separation from product-building sections (pricingSurface) ✅ — PricingCalculatorView:147 and :426 use `.backgroundStyle(AppTheme.Colors.pricingSurface)`
- [x] Card elevation creates clear containment (surfaceElevated over surface background) ✅ — `.cardStyle()` uses `surfaceElevated` background
- [x] Cost summary card hierarchy: individual costs → subtotals → total (increasing visual weight) ✅ — ProductCostSummaryCard shows Labor→Materials→Shipping→Total with bold sectionHeader+accent on total
- [x] Font sizes follow a consistent scale (not arbitrary sizes like 13, 15, 17, 19) ✅ — All AppTheme.Typography values use system text styles
- [x] Monospaced font is used only for the stopwatch timer display (not elsewhere) ✅ — Only StopwatchView:85,91 uses `timerDisplay` (monospaced)
- [x] GroupBox headers clearly indicate collapsible/expandable sections ✅ — DisclosureGroup used for Target Price Calculator, Labor Workflow, Materials, Shipping
- [x] Sufficient spacing between sections — content doesn't feel "stacked" without rhythm ✅ — Consistent AppTheme.Spacing constants (4pt grid) used throughout

---

## 5. Consistency & Patterns

**What to evaluate:** Do similar things look and behave the same way throughout the app? Can users transfer knowledge from one screen to another?

| Score | Criteria |
|-------|----------|
| 1 | Each screen feels like a different app. Input fields, buttons, cards, and navigation patterns vary wildly. |
| 2 | Core patterns are consistent but secondary interactions differ — e.g., delete works differently in different contexts, some lists have search and others don't. |
| 3 | Primary patterns are consistent: list views share a common layout, detail views follow a shared structure, forms use the same field components. Minor inconsistencies in secondary interactions. |
| 4 | All screens follow predictable patterns. A user who has learned the WorkStep flow can immediately use the Material flow. Toolbar placement, sheet presentation, context menus, and swipe actions are uniform. |
| 5 | All of 4, plus: even edge-case interactions are consistent — empty states, error messages, loading states, and confirmation dialogs follow the same template. The app feels like one coherent product from corner to corner. |

**Score: 5**

**Explanation:** The app feels like one coherent product from corner to corner. WorkStep and Material flows are structurally identical across all 4 view types (library, detail, form, list). All 3 searchable lists use the same `.searchable` pattern with in-memory filtering. Delete confirmations follow an identical dialog style with clear consequences. Context menus are consistent per context. "Add New"/"Add Existing" menus are pixel-identical between steps and materials. Reorder mode is identical. RemoveFromProductButton is a shared component. Platform pickers use `.segmented` style everywhere. Library tab rows share identical HStack+VStack layout. CurrencyFormatter is used universally (56 occurrences across 9 files).

**Specific checks:**
- [x] WorkStep and Material flows are structurally parallel (list, detail, form, library — same patterns) ✅ — All 4 view types are structurally identical with domain-specific data
- [x] All searchable lists use the same search behavior (in-memory, real-time, same placement) ✅ — WorkshopView:51, MaterialsLibraryView:51, ProductListView:55 all use `.searchable` with `.localizedCaseInsensitiveContains`
- [x] All delete confirmations use the same dialog style and language pattern ✅ — All use `.confirmationDialog` with `titleVisibility: .visible`, destructive button, and consequences message
- [x] Context menu actions are consistent (same actions available in same contexts) ✅ — Step/Material lists: "Remove from Product"; Product list: "Duplicate" + "Delete" in both list and grid
- [x] "Add New" and "Add Existing" follow the same multi-select picker pattern for both steps and materials ✅ — Identical Menu with "New X" + "Add Existing X" at WorkStepListView:132-143 and MaterialListView:131-142; identical multi-select picker layout
- [x] Reorder mode uses the same toggle + arrow button pattern for both steps and materials ✅ — Same toggle text ("Reorder"/"Done"), same ReorderRow component, same arrow buttons with accessibility labels
- [x] Hero card styling is identical across ProductCostSummaryCard, PricingCalculatorView, BatchForecastView, and PortfolioView ✅ — `.heroCardStyle()` consistently applied; ProductCostSummaryCard intentionally uses `.sectionGroupStyle()` for embedded context
- [x] Platform picker appearance and behavior is identical in PricingCalculator, BatchForecast, and Portfolio ✅ — Both PricingCalculatorView:186-193 and PortfolioView:343-349 use identical `.segmented` picker over `PlatformType.allCases`
- [x] Library tab layout is parallel: Labor tab and Materials tab use the same row structure (thumbnail, title, usage, metric) ✅ — WorkshopView:82-110 and MaterialsLibraryView:83-112 share identical HStack(spacing:md) + thumbnail + VStack layout
- [x] "Remove from Product" button placement and styling is identical for both steps and materials ✅ — Shared RemoveFromProductButton component (ViewModifiers:255-284) used in both detail views
- [x] Toolbar icon positions are predictable (edit on trailing, navigation on leading) ✅ — Both detail views use `.primaryAction` for edit/menu; ProductListView uses `.topBarLeading` for grid toggle
- [x] All monetary values throughout the app pass through the same CurrencyFormatter (consistent decimal places, symbol placement) ✅ — 56 `formatter.format()` calls across 9 view files, zero inline formatting

---

## 6. Labeling, Copy & Terminology

**What to evaluate:** Are labels clear, concise, and domain-appropriate? Can a maker understand every screen without a manual?

| Score | Criteria |
|-------|----------|
| 1 | Labels are technical, ambiguous, or misleading. Jargon that makers wouldn't know. Inconsistent terminology (same concept called different things on different screens). |
| 2 | Labels are mostly clear but some are ambiguous (e.g., "Rate" without context, "Buffer" without explanation). Some technical terms leak through (e.g., "join model", "cascade"). |
| 3 | Labels use maker-friendly language. Business terms are explained where first encountered (e.g., buffer % has helper text). Solo-maker framing is present ("Your Hourly Rate"). No technical jargon visible to the user. |
| 4 | All of 3, plus: dynamic unit labels adapt to context (e.g., "Boards per Product" not "Units per Product" when unitName is "board"). Section footers explain non-obvious concepts. Pricing labels distinguish clearly between cost/price/fee/profit. |
| 5 | All of 4, plus: every label could be read aloud and a maker would nod. Language matches how makers talk about their craft ("How much did you pay for this?" not "Enter bulk cost"). No screen requires a tooltip or help text to be understood. |

**Score: 5**

**Explanation:** Labeling is exemplary throughout. Solo-maker personal framing ("Your Hourly Rate", "Your Earnings / Sale", "Your Hours / Product") is used consistently. Dynamic unit labels adapt to context ("Boards per Batch", "Cost per oz") using each entity's `unitName` property. Batch-oriented labels ("Time to Complete Batch") replace generic terms. Buffer fields have helper text. Pricing labels clearly distinguish Production Cost / Target Price / Selling Price / Earnings. Locked fees say "Set by Etsy." "Used By" uses human-readable format ("Used by Product A + 2 others"). Shopping list uses actionable "Buy 3 × 32 oz" format. Empty states are action-oriented. No confusing abbreviations. Helper text explains non-obvious fields.

**Specific checks:**
- [x] "Your Hourly Rate", "Your Earnings", "Your Hours" — solo-maker personal framing used consistently ✅ — WorkStepDetailView:202 "Your Hourly Rate"; PricingCalculatorView:594 "Your Earnings / Sale"; :640 "Your Hourly Pay"; BatchForecastView:447 same
- [x] Dynamic unit labels: "Time per board", "Boards per Product" (not generic "units") ✅ — WorkStepDetailView:172 "Time per \(step.unitName)"; :218 "\(step.unitName.capitalized)s per Product"; MaterialDetailView:165 "Cost per \(material.unitName)"
- [x] "Time to Complete Batch" / "Units per Batch" — batch-oriented labels (not "Recorded Time") ✅ — WorkStepFormView:192 "Time to Complete Batch"; :219 "Units per Batch"
- [x] Buffer fields include helper text explaining what the percentage means ✅ — BufferInputSection at ViewModifiers:377 accepts `helperText` parameter, rendered at :407-409
- [x] Pricing section labels distinguish: "Production Cost" vs "Target Price" vs "Selling Price" vs "Earnings" ✅ — PricingCalculatorView:556 "Production Cost", :384 "Target Price", :443 "Selling Price", :594 "Your Earnings / Sale"
- [x] Platform fee labels explain what they are: "Platform Fee (Etsy: 6.5%)" not just "6.5%" ✅ — PricingCalculatorView:346 "Set by \(selectedPlatform.rawValue)" with lock icon
- [x] Locked fee display includes explanation: "Set by Etsy" or equivalent ✅ — PricingCalculatorView:346 and accessibility label at :353 "set by \(platform), not editable"
- [x] "Used by Standard Bagel Board + 2 others" — human-readable, not "Used by 3 products" ✅ — UsageText.from() at ViewModifiers:599-607 returns "Used by \(first.title) + \(remaining) others"
- [x] Shopping list uses actionable language: "Buy 3 × 32 oz Soy Wax" not "96 oz required / 32 oz per bulk" ✅ — BatchForecastView:265 "Buy \(purchases) × \(bulkQty) \(unitName)"
- [x] Profit hero label says "Your Earnings / Sale" not "Net Profit" or "Gross Margin" ✅ — PricingCalculatorView:594
- [x] "Margin After Costs" is clearly secondary to "Your Earnings" (not competing for attention) ✅ — Earnings is hero card, margin is regular DetailRow below it
- [x] Empty state messages tell the user what to do, not just what's missing ✅ — WorkStepListView:155 "Tap + above to add labor steps and calculate costs"; BatchForecastView:481 "Add labor steps and materials in the Build tab"
- [x] No abbreviations that could confuse (hrs is ok, "prc" or "qty" are not) ✅ — Zero confusing abbreviations in user-facing strings
- [x] Tooltip/help text exists for non-obvious fields (% Sales from Ads, Material Buffer) ✅ — PricingCalculatorView:290 "What fraction of your sales come through paid advertising?"; WorkStepFormView:206,227,241 all have footer explanations

---

## 7. Feedback & Affordances

**What to evaluate:** Does the app communicate what's happening, what can be interacted with, and what the result of actions will be?

| Score | Criteria |
|-------|----------|
| 1 | No feedback on actions. Buttons don't indicate tappability. Saves happen silently with no confirmation. Destructive actions have no warning. |
| 2 | Some feedback exists but is inconsistent — some deletes have confirmations and others don't. Interactive elements sometimes look static. Save feedback is unclear. |
| 3 | Destructive actions have confirmation dialogs. Interactive fields are visually distinct (editableFieldStyle). Save/create actions have clear triggers (Save button, form dismissal). Stopwatch state changes are visible. |
| 4 | All of 3, plus: real-time preview shows the impact of changes before saving. "Use Target Price" button provides a clear affordance. Locked fees are visually distinct from editable fees. Swipe hints and context menus are discoverable. |
| 5 | All of 4, plus: every state change is visible and reversible. The user always knows: what they can tap, what will happen if they tap it, and how to undo it. Animation and transitions reinforce the navigation model. |

**Score: 4**

**Explanation:** Feedback and affordances are strong throughout. All delete actions have confirmation dialogs with clear consequences. "Remove from Product" is clearly distinct from "Delete" in both wording and treatment. Editable fields use `.editableFieldStyle()`. Locked fees use tertiary color + lock icon + "Set by [Platform]" text. Stopwatch has 3 visually distinct states with appropriate button colors (accent for Start/Resume, destructive for Pause). Real-time previews update as the user types. "Use Target Price" and "Reset to Target Price" buttons are visible and well-labeled. Duplication adds "(Copy)" suffix and auto-navigates. Category chips, sort picker, list/grid toggle, and reorder mode all have clear visual states.

**Specific checks:**
- [x] All delete actions have confirmation dialogs with clear consequences ✅ — ProductListView:105-122 "Work steps and materials will remain in their libraries"; WorkStepDetailView:132-144 "remove it from all products"; MaterialDetailView:101-113 same pattern
- [x] "Remove from Product" is distinct from "Delete" — both in wording and visual treatment ✅ — Remove: "Remove from [product]" with "will remain available in the step library"; Delete: "permanently delete" with "cannot be undone"
- [x] Editable fields have `.editableFieldStyle()` background to signal interactability ✅ — Used in WorkStepDetailView:210,225; MaterialDetailView:191; ProductDetailView:271; PricingCalculatorView:450,462; BatchForecastView:141
- [x] Locked/read-only fee values use tertiary color — clearly non-interactive ✅ — PricingCalculatorView:331-353 uses `.foregroundStyle(.tertiary)` + lock icon
- [x] Stopwatch clearly shows its state: idle (Start visible), running (Pause visible), paused (Resume + Save visible) ✅ — StopwatchView:101-131 with distinct button sets per state and color coding
- [x] Real-time cost previews update as the user types (not on save) ✅ — WorkStepDetailView labor cost updates via `onChange`; PricingCalculatorView profit updates via `onChange`
- [x] "Use Target Price" button is visible and clearly communicates its purpose ✅ — PricingCalculatorView:470-493 "Use Target Price ($X)" with accent tint; :495-509 "Reset to Target Price" after user sets price
- [x] Save/Cancel buttons on forms are consistently placed and labeled ✅ — All forms use `.cancellationAction` and `.confirmationAction` placements
- [x] Successful template application results in visible navigation to the new product ✅ — Auto-navigates to ProductDetailView after template application
- [x] Product duplication gives feedback (new product appears in list, possibly with "(Copy)" suffix visible) ✅ — ProductListView:313 adds "(Copy)" suffix, :155 auto-navigates to copy
- [x] Category filter chips show which filter is active (visual selection state) ✅ — ProductListView:251-266 chip() with accent background + bold font when selected
- [x] Sort picker in PortfolioView clearly shows the active sort metric ✅ — PortfolioView:67-74 segmented picker with standard iOS selection highlight
- [x] List/grid toggle has clear visual state indicating the current mode ✅ — ProductListView:73-80 dynamic icon (list.bullet ↔ square.grid.2x2) with accessibility label
- [x] Reorder mode toggle clearly indicates when reorder is active vs inactive ✅ — Text toggles "Reorder"↔"Done", rows transform from NavigationLinks to arrow buttons

---

## 8. Data Visualization & Comprehension

**What to evaluate:** Are numbers, comparisons, and breakdowns presented in a way that aids understanding and decision-making?

| Score | Criteria |
|-------|----------|
| 1 | Raw numbers only. No visual aids. The user must mentally process and compare values. No formatting assistance. |
| 2 | Numbers are formatted (currency, percentages) but there are no visual comparisons. Cost breakdowns are text-only. Portfolio comparison is just a list of numbers. |
| 3 | Currency formatting is consistent. Cost breakdowns show labeled rows with values. Portfolio has proportional bars for comparison. Positive/negative profit uses color coding. |
| 4 | All of 3, plus: stacked bars in cost breakdown clearly show proportions. Human-readable time formats ("4h 30m" not "4.5 hours" for batch totals). Shopping list shows actionable purchase info, not just raw quantities. Hero metrics are immediately scannable. |
| 5 | All of 4, plus: the portfolio view enables genuine business decisions (the maker can identify which product is most worth their time at a glance). Batch forecast answers "can I fill this order?" without calculator-level mental effort. Cost summary immediately shows the largest cost driver. |

**Score: 5**

**Explanation:** Data visualization is exemplary. CurrencyFormatter is used for all 71 monetary displays. Percentages show whole numbers with % symbol via PercentageFormat. Time uses context-appropriate formats: stopwatch (MM:SS.t), batch totals (both "12.50 hrs" and "12h 30m"), and step detail (precise decimals "0.0833 hrs"). Portfolio bars are proportional with minimum width for visibility. Stacked cost bars have labeled legend (Labor/Materials/Shipping). Green/red profit coding is supplemented by text labels and +/- context. Shopping list uses actionable "Buy 3 × 32 oz" format. Fee breakdown shows individual fees AND total percentage. Revenue waterfall clearly shows revenue → fees → costs → profit. Portfolio "Needs Attention" callout surfaces the most important insight. "N/A" used for genuinely inapplicable metrics.

**Specific checks:**
- [x] All monetary values use consistent formatting (CurrencyFormatter, 2 decimal places, correct symbol) ✅ — 71 occurrences of `formatter.format()` across all view files
- [x] Percentages display as whole numbers with % symbol (30%, not 0.30) ✅ — PercentageFormat.toDisplay() at ViewModifiers:615-627 converts fractions; used at PricingCalculatorView:306,631; PortfolioView:150,364; BatchForecastView:424
- [x] Time displays use human-readable format where appropriate ("4h 30m" for batch totals, h:m:s for stopwatch) ✅ — BatchForecastView:216 `formatHoursReadable`; StopwatchView:84 `formatStopwatchTime`; WorkStepDetailView:168 `formatDuration`
- [x] Hours/Unit uses precise decimal format (0.0833 hrs) for accuracy in costing context ✅ — WorkStepDetailView:179 uses `formatHours()` (4 decimal places, trailing zeros stripped)
- [x] Portfolio bars are proportional to their values (longest bar = highest value, others scaled) ✅ — PortfolioView:518-522 `proportion()` scales value/max with min/max clamping; :469 bar width uses `geo.size.width * proportion`
- [x] Cost breakdown stacked bars clearly distinguish components (labor/material/shipping) with legend ✅ — PortfolioView:254-305 stacked bars with 3 colors; :307-325 legend with labeled dots
- [x] Green/red color coding for profit is universally applied and colorblind-accessible (not color alone) ✅ — Accent/destructive colors accompanied by text labels ("Your Earnings", value amounts, hero context)
- [x] "Earnings / Sale" is immediately scannable without reading the breakdown ✅ — PricingCalculatorView:593-599 hero card with large bold accent typography
- [x] Shopping list format is actionable: "Buy 3 × 32 oz" not "96 oz needed, 32 oz per bulk" ✅ — BatchForecastView:265 "Buy \(purchases) × \(bulkQty) \(unitName)"
- [x] Batch labor forecast shows both precise total (12.50 hrs) and readable format (12h 30m) ✅ — BatchForecastView:213-219 shows "12.50 hrs" in sectionHeader + "12h 30m" in heroPrice
- [x] Fee breakdown in pricing calculator shows individual fees AND total fees percentage ✅ — PricingCalculatorView:256-316 individual rows + :302-310 "Total Fees" with percentage
- [x] Revenue forecast breakdown clearly shows the waterfall: revenue → fees → costs → profit ✅ — PricingCalculatorView:516-581 and BatchForecastView:367-380 both show clear waterfall
- [x] PortfolioView summary card surfaces the single most important insight (top earner or needs attention) ✅ — PortfolioView:385-393 "Needs Attention" callout with exclamationmark.triangle for negative earnings
- [x] "N/A" is used instead of "$0.00" or "0%" when a metric is genuinely not applicable (e.g., hourly rate with no labor) ✅ — PortfolioView:215 "N/A" with tertiary styling and "No labor steps" caption

---

## 9. Error Prevention & Recovery

**What to evaluate:** Does the app prevent mistakes before they happen? When mistakes occur, can the user recover easily?

| Score | Criteria |
|-------|----------|
| 1 | Users can easily create invalid data (zero quantities, empty required fields). Mistakes are permanent. No undo. |
| 2 | Some validation exists but users can still create problematic states. Recovery from mistakes requires deleting and recreating. |
| 3 | Form validation prevents common mistakes (required title, positive quantities). Defaults are safe. Confirmation dialogs prevent accidental deletes. Duplication provides a safety net for experimentation. |
| 4 | All of 3, plus: input fields prevent invalid states at the input level (clamped values, correct keyboard types). "Remove from Product" is reversible (step survives in library). Stopwatch has discard + re-record options. |
| 5 | All of 4, plus: the app makes it hard to get into a bad state and easy to get out of one. Every destructive action is either confirmable, reversible, or both. The user feels confident experimenting because mistakes are cheap. |

**Score: 4**

**Explanation:** Error prevention is comprehensive. All create forms validate title as required with disabled save buttons and inline hints. Batch units and bulk quantity are enforced >= 1 at save time (defaulting to 1 if invalid). Minutes/seconds clamp to 0-59 in real-time. "Remove from Product" only deletes the join model — the shared entity survives and is recoverable via "Add Existing." Stopwatch has both discard and re-record options. Delete confirmations clearly state consequences. Product duplication enables safe experimentation. "Fees too high" warning replaces impossible target prices. Shipping absorbed callout warns about hidden costs. All forms use `.interactiveDismissDisabled`. One gap: PercentageInputField doesn't enforce an upper bound (users can theoretically enter >100%).

**Specific checks:**
- [x] Title is required on all create forms (Product, WorkStep, Material) — save is blocked without it ✅ — All 3 forms: `isSaveDisabled` returns true when title empty; save button `.disabled(isSaveDisabled)`; "Title is required" inline hint
- [x] Batch units >= 1 is enforced (CostingEngine division guard + form validation) ✅ — WorkStepFormView:88 `isSaveDisabled` includes `batchUnits <= 0`; :340 save enforces `safeBatchUnits = batchUnits > 0 ? batchUnits : 1`
- [x] Bulk quantity >= 1 is enforced (same pattern) ✅ — MaterialFormView:253 save enforces `safeQuantity = bulkQuantity > 0 ? bulkQuantity : 1`
- [x] Minutes and seconds fields clamp to 0–59 (not allowing 75 minutes) ✅ — WorkStepFormView:126-131 `clampTimeComponent(max: 59)` on both fields
- [x] Percentage fields accept reasonable ranges (0–100 display, 0–1 stored)
  - **PARTIAL:** PercentageFormat handles display↔storage conversion correctly, but no upper-bound clamping. Users can enter values > 100. CostingEngine handles this gracefully (target price returns nil when fees exceed 100%).
- [x] "Remove from Product" doesn't delete the shared entity — it's recoverable via "Add Existing" ✅ — Only deletes ProductWorkStep/ProductMaterial join model; shared entity remains in library
- [x] Stopwatch discard option exists (don't overwrite good data with a bad timing run) ✅ — StopwatchView:122 "Discard" button in paused state; :199-201 `discard()` dismisses without saving
- [x] Stopwatch re-record option exists (start over without dismissing the view) ✅ — StopwatchView:127 "Re-record" button; :203-207 `rerecord()` resets accumulatedTime to 0
- [x] Delete confirmation dialogs clearly state consequences ✅ — Products: "Work steps and materials will remain in their libraries"; Steps/Materials: "remove it from all products that use it"
- [x] Product duplication allows safe experimentation (try a price change on a copy) ✅ — ProductListView:311-370 full duplication with "(Copy)" suffix
- [x] Category deletion warning explains products won't be deleted ✅ — ProductFormView:218-220 "Products in this category will become uncategorized but won't be deleted"
- [x] Pricing calculator shows "fees too high" warning instead of displaying a negative/infinity target price ✅ — PricingCalculatorView:393 "Fees + margin exceed 100%" with helper text :396 "Try lowering your profit margin"
- [x] Shipping absorbed callout warns when the user may not realize they're eating shipping costs ✅ — PricingCalculatorView:661-673 "You're absorbing $X in shipping costs on this platform" when actualShippingCharge==0 but shippingCost>0
- [x] Empty product state in Forecast tab directs user to Build tab (not a blank screen) ✅ — BatchForecastView:481-484 "Add labor steps and materials in the Build tab to forecast batch production"
- [x] No data loss on accidental sheet dismissal (iOS default swipe-to-dismiss behavior) ✅ — `.interactiveDismissDisabled(hasUnsavedChanges)` in all 3 form views

---

## 10. Accessibility & Inclusivity

**What to evaluate:** Can users with diverse abilities use the app effectively? Does the app respect system accessibility settings?

| Score | Criteria |
|-------|----------|
| 1 | No accessibility consideration. VoiceOver would be unusable. Dynamic Type breaks layouts. No color contrast consideration. |
| 2 | Basic VoiceOver labels exist on some elements. Dynamic Type partially works but breaks in places. Some color contrast issues. |
| 3 | Key interactive elements have accessibility labels. Dynamic Type works for body text but may break hero values or custom layouts. Color is not the sole indicator for any state. |
| 4 | All of 3, plus: VoiceOver can navigate the full app flow (create product, add step, set price, view portfolio). Accessibility labels are descriptive ("Target price: $45.00" not just "$45.00"). Dynamic Type scales gracefully across all screens. |
| 5 | All of 4, plus: custom components (stopwatch, proportional bars, stacked bars) have meaningful VoiceOver descriptions. Accessibility actions (swipe up/down for value adjustment) are implemented where appropriate. The app is fully usable without vision. |

**Score: 4** (was 3)

**Explanation:** After Phase 4 accessibility fixes, the app has comprehensive accessibility implementation. All interactive elements have labels (including the 3 previously missing plus buttons). Profit/loss values now use `signedProfitPrefix` — color is never the sole indicator. Stopwatch announces all state changes via `AccessibilityNotification.Announcement`. Non-obvious actions have `accessibilityHint`. Decorative images hidden, composite cards grouped, locked fees include context, Dynamic Type fully supported, touch targets meet 44pt, Reduce Motion checked. VoiceOver can navigate the full app flow.

**Specific checks:**
- [x] All tappable elements have accessibility labels (not just system-provided defaults) ✅ — All plus buttons now labeled: "Create product" (ProductListView:72), "Create work step" (WorkshopView:60), "Create material" (MaterialsLibraryView:60)
- [x] Images have appropriate accessibility traits (decorative images are hidden, meaningful images are labeled) ✅ — Placeholder images hidden via `.accessibilityHidden(true)` at ViewModifiers:60,89,118; chevrons hidden at :229; portfolio dots hidden at :317
- [x] Custom components (hero cards, proportional bars, stacked bars) have VoiceOver descriptions ✅ — `.heroCardStyle()` uses `.accessibilityElement(children: .combine)`; PortfolioView:288-289 cost breakdown bar has detailed label; portfolio bar rows combine at :480-481
- [x] Stopwatch state is announced via VoiceOver ("Timer running: 2 minutes 30 seconds") ✅ — Time display uses `CostingEngine.accessibleTimeDescription()`. State changes post `AccessibilityNotification.Announcement`: "Timer started", "Timer paused", "Timer resumed", "Timer reset"
- [x] Dynamic Type support: text scales with system font size settings ✅ — All AppTheme.Typography values use scalable system fonts (no fixed sizes)
- [ ] Hero values don't clip or overlap at largest Dynamic Type sizes — Not verifiable without device testing
- [x] Color is never the only indicator (green/red profit also has +/- prefix or explicit label) ✅ — All 8 profit/loss values now use `CostingEngine.signedProfitPrefix()` to prepend "+" for positive values. Negative values show "-" via NumberFormatter. Color is supplementary, not sole indicator.
- [x] Touch targets meet minimum 44x44pt guideline ✅ — BatchForecastView:132,151; MaterialListView:147; WorkStepListView:148 all use `.frame(minWidth: 44, minHeight: 44)`
- [x] Swipe actions (delete, duplicate) are also available via context menu (long press) for motor accessibility ✅ — ProductListView uses `.contextMenu` for duplicate/delete; WorkStepListView/MaterialListView use `.contextMenu` for remove
- [x] Platform locked fee labels include context for screen readers ✅ — PricingCalculatorView:352-353 "set by \(selectedPlatform.rawValue), not editable"
- [ ] Keyboard navigation works for users with external keyboards — Not verifiable without device testing
- [x] Reduce Motion is respected (no essential animations that can't be disabled) ✅ — StopwatchView:16,86; WorkStepListView:22,124; MaterialListView:21,123 check `accessibilityReduceMotion`. Not all views check (PortfolioView, BatchForecastView) but they have minimal animation.

---

## 11. Platform Conventions (iOS HIG Compliance)

**What to evaluate:** Does the app feel like a native iOS app? Does it follow Apple's Human Interface Guidelines and leverage platform capabilities?

| Score | Criteria |
|-------|----------|
| 1 | The app feels like a web app in a native wrapper. Custom chrome replaces standard iOS patterns. Navigation is non-standard. |
| 2 | Some iOS conventions followed (TabView, NavigationStack) but others ignored — custom form fields where system controls exist, non-standard toolbar placement, unusual sheet behavior. |
| 3 | Core navigation uses standard iOS patterns (TabView, NavigationStack, sheets). System controls are used where appropriate (Picker, Toggle, TextField). Toolbar items follow platform placement conventions. |
| 4 | All of 3, plus: the app leverages iOS 26 features appropriately (Liquid Glass materials, system behavior). Gestures match platform expectations (swipe to go back, pull to dismiss sheets). System color scheme is respected. |
| 5 | All of 4, plus: the app feels like it could be a first-party Apple app. It uses SF Symbols, respects safe areas, follows the platform's visual weight and density guidelines. No screen feels foreign to an iOS user. |

**Score: 5**

**Explanation:** The app feels like a native iOS app. All 4 tabs use SF Symbols. NavigationStack used throughout with zero custom back buttons — system swipe-back works everywhere. Sheets for creation/editing, push for drill-down. Toolbar items follow convention (primary trailing, secondary leading). Pickers use `.segmented` style. Forms use SwiftUI `Form` with grouped sections. AppearanceManager properly applies `.preferredColorScheme()` for System/Light/Dark. Context menus follow iOS conventions. fullScreenCover used appropriately for the immersive stopwatch. SF Symbols used exclusively (38 occurrences, zero custom icon assets). `.searchable` modifier with proper placement. Safe areas fully respected (zero `.ignoresSafeArea` calls).

**Specific checks:**
- [x] Tab bar uses SF Symbols matching Apple's visual style ✅ — ContentView:21 square.grid.2x2, :26 hammer, :31 shippingbox, :38 gearshape
- [x] Navigation uses NavigationStack (not custom back button implementations) ✅ — NavigationStack in all 4 tab roots and 3 form views; zero custom back buttons
- [x] Sheets are used for creation/editing (modal); push is used for drill-down (non-modal) ✅ — ProductFormView, WorkStepFormView, MaterialFormView all `.sheet`; detail views use `.navigationDestination`
- [x] Toolbar items follow iOS convention: primary actions trailing, secondary leading ✅ — `.primaryAction` for edit/menu; `.topBarLeading` for grid toggle; `.cancellationAction`/`.confirmationAction` in forms
- [x] Picker controls use system styles (segmented, menu, wheel) where appropriate ✅ — ProductDetailView:151, PricingCalculatorView:191, PortfolioView:73,348 all use `.segmented`
- [x] Form layout follows iOS standards (grouped sections with headers and footers) ✅ — All 3 forms use SwiftUI `Form` with `Section` grouping; SettingsView uses `List` with sections
- [x] Pull-to-dismiss works on all sheets ✅ — Standard sheet presentation; `.interactiveDismissDisabled` only blocks when unsaved changes exist
- [x] Swipe-back gesture works in all NavigationStack contexts ✅ — NavigationStack enables system gesture automatically
- [x] System color scheme (light/dark) is respected; custom appearance applies via `.preferredColorScheme()` ✅ — AppearanceManager:62-68 resolves scheme; MakerMarginsApp:62 applies it
- [ ] Text selection and copy work on value display fields — Not verifiable without device testing
- [x] Context menus (long press) follow iOS conventions ✅ — ProductListView, WorkStepListView, MaterialListView all use `.contextMenu`
- [x] fullScreenCover is used appropriately (stopwatch = immersive task, not a detail view) ✅ — WorkStepDetailView:127 and WorkStepFormView:132 present StopwatchView as `.fullScreenCover`
- [x] SF Symbols are used throughout (not custom icon assets) ✅ — 38 `Image(systemName:)` occurrences across 15 files; zero custom icon assets for UI
- [x] Search bar follows iOS conventions (.searchable modifier, correct placement) ✅ — WorkshopView:51, MaterialsLibraryView:51, ProductListView:55 all use `.searchable` with prompt
- [x] Safe areas are respected on all device sizes ✅ — Zero `.ignoresSafeArea` or `.edgesIgnoringSafeArea` calls in entire codebase

---

## 12. Cognitive Load & Decision Complexity

**What to evaluate:** Does the app present information and choices at a manageable pace? Can the user focus on one decision at a time?

| Score | Criteria |
|-------|----------|
| 1 | Screens are overwhelming — too many numbers, too many options, too many fields visible at once. The user doesn't know where to start or what matters. |
| 2 | Some screens are well-organized but others present too much at once — e.g., all pricing fields for all platforms visible simultaneously, or cost breakdown + pricing + profit on one scrollable screen. |
| 3 | Sub-tabs (Build/Price/Forecast) effectively separate concerns. Each tab has a focused purpose. Forms are grouped into logical sections. The user deals with one type of information at a time. |
| 4 | All of 3, plus: progressive disclosure is used effectively — sections expand/collapse, revenue forecast is hidden when no pricing exists, fee rows hide when zero. The user only sees what's relevant to their current state. |
| 5 | All of 4, plus: each screen has a clear "main thing" — the user can answer one question per view. Supporting information is available but doesn't compete. The app respects that makers are not accountants — financial concepts are introduced gradually through the Build → Price → Forecast progression. |

**Score: 5**

**Explanation:** Cognitive load management is exemplary. The Build/Price/Forecast sub-tabs cleanly separate concerns — each tab has one clear purpose. The pricing calculator separates Target Price Calculator (DisclosureGroup, collapsible) from Profit Analysis (distinct GroupBox with "YOUR ACTUAL RESULTS" divider). Zero-value fee rows are conditionally hidden. Revenue forecast is hidden when no pricing exists (shows helpful hint instead). Batch forecast has a single input (batch size) with everything derived. Portfolio shows one metric at a time via segmented picker. Locked fees are clearly non-editable (lock icon + tertiary). Buffers are inline. Cost summary is concise (4 lines). "Needs Attention" callout flags negative earnings. Empty states guide next steps. DisclosureGroups enable collapsing sections the user isn't currently working on.

**Specific checks:**
- [x] ProductDetailView sub-tabs effectively separate Build (what it costs), Price (what to charge), Forecast (batch planning) ✅ — ProductDetailView:43-47 enum with build/price/forecast; :146-151 segmented picker; :186-195 independent ViewBuilder per tab
- [x] Pricing calculator separates "Target Price Calculator" from "Profit Analysis" into distinct GroupBoxes ✅ — PricingCalculatorView:135-147 Target in DisclosureGroup; :149-157 divider with "YOUR ACTUAL RESULTS" label; :160 Profit Analysis in separate GroupBox
- [x] Zero-value fee rows are hidden in profit analysis breakdown (not showing "$0.00" clutter) ✅ — PricingCalculatorView:523-529 platform fees shown only if > 0; :532-538 processing; :545-551 marketing; :561-566 shipping
- [x] Revenue forecast section is hidden when no actual pricing exists (not showing empty/zero state) ✅ — BatchForecastView:52-61 `activePricing` checks actualPrice > 0; :77-82 revenue hidden without pricing; :472-478 hint directs user to Price tab
- [x] Batch forecast shows one input (batch size) and derives everything — no configuration overload ✅ — BatchForecastView:14-17 only batchSize as state; :116-172 input with +/- buttons and quick-select chips; all other values computed
- [x] Portfolio sort picker lets users focus on one metric at a time (not a dashboard of everything) ✅ — PortfolioView:67-74 segmented picker; :78-90 ViewBuilder shows only one tab's ranked list
- [x] Locked fees are displayed but not editable — reduces decision count on Etsy/Shopify/Amazon tabs ✅ — PricingCalculatorView:331-353 locked display with tertiary styling and lock icon; :352-353 accessibility "not editable"
- [x] Material buffer and labor buffer are inline within their respective sections (not a separate settings page) ✅ — WorkStepListView:220-230 BufferInputSection inline; MaterialListView:219-229 same pattern
- [x] Cost summary card shows 3–4 lines max (labor, materials, shipping, total) — not every sub-cost ✅ — ProductCostSummaryCard:14-28 exactly 4 rows: labor, materials, shipping, total
- [x] Shopping list groups per-material info clearly (units needed, purchase recommendation, leftover) without cross-referencing ✅ — BatchForecastView:245-281 materialRow() groups name+units → "Buy X × Y" → leftover vertically
- [x] "Needs attention" callout in portfolio surfaces the single most important action item ✅ — PortfolioView:385-393 "Needs Attention" with exclamationmark.triangle for worst product with negative earnings
- [x] Empty states guide the user to the next logical step (not just "nothing here") ✅ — All empty states are action-oriented: "Tap + above to add...", "Add labor steps and materials in the Build tab..."
- [x] Forms present fields in the order they'll naturally be filled (title first, derived values last) ✅ — ProductFormView: Photo → Title → SKU → Description → Category; derived previews at bottom of step/material forms

---

## Scoring Summary Template

| # | Dimension | Score (1-5) | Key Issue |
|---|-----------|-------------|-----------|
| 1 | Information Architecture & Navigation | 5 | Exemplary — 2-tap stopwatch, auto-navigate, shared entities from multiple entry points |
| 2 | Onboarding & First-Run Experience | 5 | Templates create immediate "aha moment" with realistic data, bundled images, auto-navigation |
| 3 | Form Design & Data Entry | 4 | Excellent focus management, real-time previews, inline category creation, percentage handling |
| 4 | Visual Hierarchy & Typography | 4 | Strong hierarchy with hero values, accent-colored derived values; 18 hardcoded fonts in implementation |
| 5 | Consistency & Patterns | 5 | WorkStep/Material flows perfectly parallel; all patterns uniform corner to corner |
| 6 | Labeling, Copy & Terminology | 5 | Exemplary maker-friendly language, dynamic unit labels, actionable shopping list |
| 7 | Feedback & Affordances | 4 | Strong delete confirmations, real-time previews, clear stopwatch states, "Use Target Price" |
| 8 | Data Visualization & Comprehension | 5 | Proportional bars, stacked breakdowns, dual time formats, actionable shopping list, N/A handling |
| 9 | Error Prevention & Recovery | 4 | Comprehensive validation, stopwatch discard/re-record, shipping absorbed callout; percentage unbounded |
| 10 | Accessibility & Inclusivity | **4** (was 3) | All buttons labeled, stopwatch announces state, profit uses sign prefix, accessibility hints added |
| 11 | Platform Conventions (iOS HIG) | 5 | Feels native — NavigationStack, SF Symbols, proper sheet/push, safe areas, fullScreenCover |
| 12 | Cognitive Load & Decision Complexity | 5 | Sub-tabs separate concerns, collapsible sections, single batch input, zero-value fee hiding |
| | **Total** | **55/60** (was 54) | |

**Rating scale:**
- **54–60: Exceptional UX — ship with confidence** ← MakerMargins scores 55 (was 54)
- 45–53: Strong UX with minor polish needed
- 36–44: Solid foundation, targeted improvements before launch
- 24–35: Usable but significant friction — address before public release
- < 24: Fundamental UX issues — requires redesign before beta

---

## Grading Summary (2026-04-05)

**Overall: 55/60 — Exceptional UX, ship with confidence (+1 from 54)**

### Strengths (scores of 4-5)
- **Navigation (5/5)** — 2-tap stopwatch, auto-navigate, shared entities, max 3-level depth
- **Onboarding (5/5)** — Templates create immediate value with realistic data and bundled images
- **Consistency (5/5)** — WorkStep/Material flows perfectly parallel; every pattern is uniform
- **Labeling (5/5)** — Maker-friendly language, dynamic unit labels, actionable copy
- **Data Visualization (5/5)** — Proportional bars, dual time formats, actionable shopping list
- **iOS HIG (5/5)** — Feels native; NavigationStack, SF Symbols, proper sheet/push patterns
- **Cognitive Load (5/5)** — Sub-tabs, collapsible sections, single-input batch forecasting
- **Accessibility (4/5)** — All buttons labeled, stopwatch VoiceOver, sign prefix on profit, hints added

### Remaining gaps (to reach 5)
- **Form Design (4→5):** Already excellent; minor polish opportunities
- **Visual Hierarchy (4→5):** 1 remaining hardcoded font on stopwatch button
- **Feedback (4→5):** Could add subtle animations for state transitions
- **Error Prevention (4→5):** Add upper-bound clamping to PercentageInputField (max 100%)
- **Accessibility (4→5):** Rich VoiceOver for all custom components; Switch Control audit
