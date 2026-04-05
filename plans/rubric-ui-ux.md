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

**Specific checks:**
- [ ] Stopwatch is reachable in 2 taps from the Labor tab (the fastest path for a maker mid-production)
- [x] Product detail view sub-tabs (Build/Price/Forecast) are discoverable without instruction
- [x] Shared entities are accessible from both their library tab AND from within product detail
- [ ] "Used By" sections show where an item is linked without requiring navigation
- [x] Portfolio view is discoverable from the Products tab (toolbar icon is recognizable)
- [x] Back navigation is always available and returns to the expected screen
- [x] Sheet vs push navigation is used appropriately (sheets for creation/editing, push for drill-down)
- [x] The user is never more than 3 taps from the tab root
- [ ] Navigation after item creation takes the user to the right place (auto-navigate to detail)
- [x] Tab badge or visual cue indicates which tab the user is on

### Audit Result: 3/5

The 4-tab structure maps cleanly to maker domains. Sub-tabs are discoverable via standard segmented picker. Sheet vs push pattern is perfectly consistent throughout. Portfolio is accessible via a labeled card (icon + "Compare your X products"), not just an unlabeled icon. However, cross-reference navigation is incomplete and the stopwatch path is too deep.

**Violations found:**

- **"Used By" products are not tappable.** In both WorkStepDetailView and MaterialDetailView, the "Used By" section displays linked products as plain text with thumbnails — but they are NOT NavigationLinks. A user viewing a shared step from the Labor tab cannot navigate to any product that uses it. They must go back, switch tabs, and find the product manually.
- **Stopwatch requires 5 taps from Labor tab.** Path: Labor list → Step detail → Edit (pencil) → Edit form → Use Stopwatch. The stopwatch is only accessible through the edit form, not directly from the detail view. CLAUDE.md states "2 taps from Labor tab" but the actual path is 5.
- **No auto-navigation after creation from library tabs.** Creating a new WorkStep from the Labor tab or a new Material from the Materials tab dismisses the form sheet but does NOT navigate to the new item's detail view. The user must find it in the list. (Auto-navigation works correctly when creating from within a product.)
- **Stopwatch close button hidden while running.** The X dismiss button in StopwatchView only appears when the timer is NOT running. A user must pause first to exit, which could be confusing.

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

**Specific checks:**
- [x] Every list view (Products, Labor, Materials) has a meaningful empty state with action guidance
- [ ] Template picker is offered prominently (not buried in a sub-menu)
- [ ] Template picker shows what each template includes (not just a name)
- [x] Templates have bundled images (populated product looks "real" immediately)
- [x] After applying a template, the user lands on the product detail with all data visible
- [x] Template products have realistic actual prices set so profit analysis works immediately
- [x] Settings defaults (labor rate, currency) are reasonable for a first-time user
- [x] No required setup step before the user can start creating (no mandatory onboarding flow)
- [x] The "+ menu" (Blank Product / From Template) is obvious and easy to tap

### Audit Result: 3/5

Empty states provide clear action guidance. Templates are functional and include bundled images, realistic pricing, and varied workflows. A new user can have a fully populated product in 4 taps. Settings defaults are reasonable ($15/hr, USD, system appearance). However, the first-run experience doesn't create the "aha moment" that demonstrates the app's core value.

**Violations found:**

- **Template picker is buried in a sub-menu.** The "From Template" option requires tapping "+", then selecting from a Menu. On the empty-state first launch, the primary CTA says "Tap + to create a blank product or start from a template" — but "From Template" is the second item in a dropdown, not a prominent standalone button.
- **No preview of what templates include.** The TemplatePickerView shows icon, title, and a one-line summary per template, but doesn't show what's inside (4 steps, 4 materials, Etsy pricing). Users must apply blind and explore.
- **No "aha moment" after template application.** User lands on the Build tab (cost breakdown) — not the Price tab where the profit analysis demonstrates the app's core value. The user must discover the Price tab on their own to see target price and earnings calculations. Template products have actual prices set, but the profit analysis isn't surfaced automatically.
- **No guidance on labor rate default.** Settings shows $15/hr but no explanatory text about why this matters or that it should be customized.

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

**Specific checks:**
- [x] All monetary fields use decimal keyboard (`.decimalPad`)
- [x] All integer quantity fields use number keyboard (`.numberPad`)
- [x] Time fields (h/m/s) clamp to valid ranges (0–59 for minutes/seconds)
- [ ] Required fields have clear validation feedback (not just a silent save failure)
- [x] Default values (1 for quantities, 0 for costs) prevent division-by-zero without user action
- [x] Focus-clear-on-tap behavior works for percentage and currency fields (clear "0" on focus, restore on blur if empty)
- [x] Real-time calculated previews show derived values (Hours/Unit, Cost/Unit) as the user fills fields
- [x] Photo picker provides Add/Change/Remove options (not just Add)
- [x] Category creation is inline from the product form (no navigation to a separate screen)
- [x] Save button is disabled when required fields are empty (not enabled with a post-tap error)
- [ ] Form preserves entered data if the user accidentally swipes to dismiss
- [x] Long text fields (description) allow multi-line input with appropriate height
- [x] Percentage fields display whole numbers (30) but store fractions (0.30) — no user confusion

### Audit Result: 3/5

Real-time previews are excellent — Hours/Unit and Cost/Unit update instantly as the user types. Focus-clear-on-tap behavior is well-implemented. Keyboard types are correct on monetary and quantity fields. Percentage conversion (type 30 → store 0.30) is seamless. Category creation is inline. However, validation is silent, data loss on dismiss is unprotected, and there's no keyboard dismissal mechanism.

**Violations found:**

- **No `.interactiveDismissDisabled()` on ANY form sheet.** ProductFormView, WorkStepFormView, and MaterialFormView can all be dismissed by a downward swipe with no warning — all entered data is lost. This is the most critical form UX gap.
- **Validation is silent.** Save button disables when title is empty or batch units are 0, but there is no visual feedback explaining WHY it's disabled. No error message, no highlighted field, no shake animation. Users may not understand what's wrong.
- **Negative values silently corrected.** MaterialFormView converts negative bulk cost to 0 and 0 bulk quantity to 1 silently on save. PricingCalculatorView silently drops negative actual prices. The user gets no feedback that their input was rejected.
- **No keyboard dismissal mechanism.** No "Done" toolbar button on any form. Users must tap outside the field to dismiss the keyboard — not discoverable.
- **Whitespace-only titles accepted.** Title validation checks `.isEmpty` but not `.trimmingCharacters(in: .whitespaces).isEmpty`. A user could create a product titled "   ".

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

**Specific checks:**
- [x] Hero values (target price, earnings/sale, total production cost) use large bold accent typography
- [x] Derived/calculated values use accent color to distinguish from user-entered values
- [ ] Section headers are visually consistent across all views (same font weight, size, icon style)
- [x] Labels use secondary/tertiary foreground — never competing with values for attention
- [x] Positive profit is green, negative profit is red — universally applied
- [x] Pricing calculator sections have visual separation from product-building sections (pricingSurface)
- [x] Card elevation creates clear containment (surfaceElevated over surface background)
- [x] Cost summary card hierarchy: individual costs → subtotals → total (increasing visual weight)
- [x] Font sizes follow a consistent scale (not arbitrary sizes like 13, 15, 17, 19)
- [x] Monospaced font is used only for the stopwatch timer display (not elsewhere)
- [x] GroupBox headers clearly indicate collapsible/expandable sections
- [x] Sufficient spacing between sections — content doesn't feel "stacked" without rhythm

### Audit Result: 4/5

The most important number on each screen is immediately obvious: total production cost on Build, target price on Price, batch earnings on Forecast, avg earnings on Portfolio. Hero values consistently use `.heroPrice` font + `.heroCardStyle()` with accent color. The 3-level hierarchy (hero → section header → body) is clear. Accent color is used sparingly and meaningfully. WorkStep and Material detail flows are perfectly parallel in visual structure.

**Violations found:**

- **ProductCostSummaryCard uses plain GroupBox** instead of the `CalculatorSectionHeader` component used everywhere else. This makes the cost summary header visually orphaned from the calculator/forecast section headers that all use icons + small-caps styling.
- **Platform picker uses different styles.** PricingCalculatorView uses `.segmented` style; PortfolioView uses `.menu` dropdown. Same logical control, different visual treatment.
- **Mixed color token for negative values.** PricingCalculatorView uses literal `.red`; BatchForecastView and PortfolioView use `AppTheme.Colors.destructive`. They're identical (`Color.red`), but the inconsistent code pattern is a minor visual hierarchy concern.
- **Some derived values use `DetailRow` instead of `DerivedRow`.** In PricingCalculatorView's production costs section, "Material Cost", "Labor Cost", and "Shipping Cost" are displayed with `DetailRow` (no accent color), making them visually indistinguishable from user-entered data. Only "Total" is manually accent-colored.

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

**Specific checks:**
- [x] WorkStep and Material flows are structurally parallel (list, detail, form, library — same patterns)
- [x] All searchable lists use the same search behavior (in-memory, real-time, same placement)
- [x] All delete confirmations use the same dialog style and language pattern
- [x] Context menu actions are consistent (same actions available in same contexts)
- [x] "Add New" and "Add Existing" follow the same multi-select picker pattern for both steps and materials
- [x] Reorder mode uses the same toggle + arrow button pattern for both steps and materials
- [ ] Hero card styling is identical across ProductCostSummaryCard, PricingCalculatorView, BatchForecastView, and PortfolioView
- [ ] Platform picker appearance and behavior is identical in PricingCalculator, BatchForecast, and Portfolio
- [x] Library tab layout is parallel: Labor tab and Materials tab use the same row structure (thumbnail, title, usage, metric)
- [x] "Remove from Product" button placement and styling is identical for both steps and materials
- [x] Toolbar icon positions are predictable (edit on trailing, navigation on leading)
- [x] All monetary values throughout the app pass through the same CurrencyFormatter (consistent decimal places, symbol placement)

### Audit Result: 4/5

A user who learns the WorkStep flow can immediately use the Material flow — list views, detail views, forms, library tabs, add/existing pickers, reorder mode, and remove-from-product buttons are all structurally identical. Delete confirmations use the same dialog pattern with clear consequence language. Search behavior is uniform. CurrencyFormatter is used everywhere. The app feels like one coherent product.

**Violations found:**

- **Platform picker style mismatch.** PricingCalculatorView uses `.pickerStyle(.segmented)` for platform selection; PortfolioView uses `.pickerStyle(.menu)` dropdown. Users see different UI patterns for the same logical control across views.
- **ProductCostSummaryCard hero styling differs.** Uses plain GroupBox with manual accent color on "Total" line, while PricingCalculatorView, BatchForecastView, and PortfolioView all use `.heroCardStyle()` modifier. The cost summary card looks visually different from other hero displays.
- **Toolbar structure differs between detail view types.** ProductDetailView uses a Menu with Edit + Delete options; WorkStepDetailView and MaterialDetailView use a direct edit pencil button + conditional delete menu. Functionally equivalent but visually different.

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

**Specific checks:**
- [x] "Your Hourly Rate", "Your Earnings", "Your Hours" — solo-maker personal framing used consistently
- [x] Dynamic unit labels: "Time per board", "Boards per Product" (not generic "units")
- [x] "Time to Complete Batch" / "Units per Batch" — batch-oriented labels (not "Recorded Time")
- [x] Buffer fields include helper text explaining what the percentage means
- [ ] Pricing section labels distinguish: "Production Cost" vs "Target Price" vs "Selling Price" vs "Earnings"
- [ ] Platform fee labels explain what they are: "Platform Fee (Etsy: 6.5%)" not just "6.5%"
- [ ] Locked fee display includes explanation: "Set by Etsy" or equivalent
- [x] "Used by Standard Bagel Board + 2 others" — human-readable, not "Used by 3 products"
- [x] Shopping list uses actionable language: "Buy 3 × 32 oz Soy Wax" not "96 oz required / 32 oz per bulk"
- [x] Profit hero label says "Your Earnings / Sale" not "Net Profit" or "Gross Margin"
- [x] "Margin After Costs" is clearly secondary to "Your Earnings" (not competing for attention)
- [ ] Empty state messages tell the user what to do, not just what's missing ("Add work steps to calculate labor costs" not "No work steps")
- [x] No abbreviations that could confuse (hrs is ok, "prc" or "qty" are not)
- [ ] Tooltip/help text exists for non-obvious fields (% Sales from Ads, Material Buffer)

### Audit Result: 3/5

Solo-maker "Your" framing is perfectly consistent throughout. Dynamic unit labels are excellent — every label uses the item's custom `unitName` (e.g., "Boards per Product", "Time per board"). Buffer helper text is clear and non-jargon. Shopping list format is actionable ("Buy 3 x 32 oz Soy Wax"). "Used By" format is human-readable. However, pricing terminology has several confusing terms that a non-technical maker would struggle with.

**Violations found:**

- **"Margin After Costs" is ambiguous.** This label excludes labor wages, but labor is added as a separate line below it to form "Your Earnings." A maker seeing "Margin After Costs: $5" then "Your Labor: $8" then "Your Earnings: $13" doesn't understand why labor is added to "margin." Rename to "Profit Before Labor Wages" or similar.
- **"Effective Hourly Rate" is jargon.** Non-technical makers don't know what "effective" means. Better: "Your Actual Hourly Rate" or "Hourly Pay."
- **"Production Costs" section includes shipping.** Shipping is not a production cost — the label is misleading. Better: "Your Costs" or "Cost Breakdown."
- **Locked fees lack platform name context.** Lock icon accessibility label says "Locked by platform" — should say "Set by Etsy" to explain WHY the fee is fixed.
- **"% Sales from Ads" is ambiguous.** Could mean "% of sales that come from ads" or "% of revenue allocated to ads." Better: "% of Sales Driven by Ads."
- **"Total Labor" and "Total Materials" are ambiguous.** Could be hours or cost. Should say "Total Labor Cost" and "Total Material Cost."
- **Some empty states describe but don't direct.** WorkStepListView says "Add work steps to calculate labor costs" — describes the benefit but doesn't say HOW (no "Tap +" instruction or button).

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

**Specific checks:**
- [ ] All delete actions have confirmation dialogs with clear consequences ("This will remove the step from all products")
- [x] "Remove from Product" is distinct from "Delete" — both in wording and visual treatment
- [x] Editable fields have `.editableFieldStyle()` background to signal interactability
- [x] Locked/read-only fee values use tertiary color — clearly non-interactive
- [x] Stopwatch clearly shows its state: idle (Start visible), running (Pause visible), paused (Resume + Save visible)
- [x] Real-time cost previews update as the user types (not on save)
- [x] "Use Target Price" button is visible and clearly communicates its purpose
- [x] Save/Cancel buttons on forms are consistently placed and labeled
- [x] Successful template application results in visible navigation to the new product
- [ ] Product duplication gives feedback (new product appears in list, possibly with "(Copy)" suffix visible)
- [x] Category filter chips show which filter is active (visual selection state)
- [x] Sort picker in PortfolioView clearly shows the active sort metric
- [x] List/grid toggle has clear visual state indicating the current mode
- [x] Reorder mode toggle clearly indicates when reorder is active vs inactive

### Audit Result: 3/5

Core interactions have good feedback. Stopwatch states are visually distinct (button color, label, and layout all change). Real-time previews work throughout. "Use Target Price" button shows the computed value in its label. Template application auto-navigates to the new product. Reorder mode clearly toggles between "Reorder" and "Done" labels with different row content.

**Violations found:**

- **Category deletion has NO confirmation dialog** in two places: CategoryListView (swipe-to-delete) and ProductFormView (inline category swipe). Users can accidentally delete categories with a single swipe gesture and no recovery path.
- **Product duplication has no feedback.** After duplicating via context menu, the new product is created with "(Copy)" suffix but there is no toast, no navigation to the copy, and no visual highlight. The user doesn't know if it worked or where the copy is.
- **Locked fee icon is too faint.** The lock icon uses `.quaternary` foreground — barely visible. Combined with no explanatory text ("Set by Etsy"), users may not understand why they can't edit certain fields.
- **"Use Target Price" button disappears.** Once the user enters any actual price, the button vanishes because `hasActualPrice` becomes true. There's no way to "revert to target price" without manually clearing the field.
- **Swipe actions are hidden affordance.** Product deletion, step/material removal from product, and category deletion are only accessible via swipe gesture or long-press context menu. No visible buttons exist for these actions in normal view mode.

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

**Specific checks:**
- [ ] All monetary values use consistent formatting (CurrencyFormatter, 2 decimal places, correct symbol)
- [x] Percentages display as whole numbers with % symbol (30%, not 0.30)
- [x] Time displays use human-readable format where appropriate ("4h 30m" for batch totals, h:m:s for stopwatch)
- [x] Hours/Unit uses precise decimal format (0.0833 hrs) for accuracy in costing context
- [x] Portfolio bars are proportional to their values (longest bar = highest value, others scaled)
- [x] Cost breakdown stacked bars clearly distinguish components (labor/material/shipping) with legend
- [x] Green/red color coding for profit is universally applied and colorblind-accessible (not color alone)
- [x] "Earnings / Sale" is immediately scannable without reading the breakdown
- [x] Shopping list format is actionable: "Buy 3 × 32 oz" not "96 oz needed, 32 oz per bulk"
- [x] Batch labor forecast shows both precise total (12.50 hrs) and readable format (12h 30m)
- [x] Fee breakdown in pricing calculator shows individual fees AND total fees percentage
- [x] Revenue forecast breakdown clearly shows the waterfall: revenue → fees → costs → profit
- [x] PortfolioView summary card surfaces the single most important insight (top earner or needs attention)
- [x] "N/A" is used instead of "$0.00" or "0%" when a metric is genuinely not applicable (e.g., hourly rate with no labor)

### Audit Result: 3/5

Currency formatting is centralized through CurrencyFormatter and used correctly in all but one place. Percentages consistently display as whole numbers. Time formats are context-appropriate (decimal for costing precision, "Xh Ym" for batch planning, "Xh Ym Zs" for stopwatch). Cost breakdown stacked bars include both visual bars and text labels (dual representation). Shopping list format is actionable. Portfolio summary card is scannable in 2-3 seconds.

**Violations found:**

- **One hardcoded "$0" in PricingCalculatorView:528.** The zero-production-cost warning message hardcodes "$0" — breaks when user switches to EUR. Should use `formatter.format(0)`.
- **Portfolio bars degrade for similar values.** When all products have similar earnings (e.g., $10, $11, $12), bar widths are 83%, 92%, 100% — visually near-identical and unhelpful for comparison. Linear scaling provides no meaningful differentiation.
- **Portfolio bars degrade for extreme outliers.** One $100 product with five $5 products renders the $5 bars at ~5% width (minimum 2px). The extreme compression makes it impossible to compare the smaller products.
- **No consistent pattern for "not entered" vs "zero" vs "N/A".** ProductCostSummaryCard shows "$0.00" for products with no materials (could mean "free materials" or "not entered yet"). PricingCalculatorView shows explanatory hints. PortfolioView uses "N/A". No global convention distinguishes these three states.
- **WorkStepDetailView shows decimal hours after human time entry.** User enters 45 minutes via stopwatch, then sees "0.75 Hours/Unit" — a cognitive disconnect. The batch forecast shows both decimal and human-readable, but the detail view shows only decimal.

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

**Specific checks:**
- [x] Title is required on all create forms (Product, WorkStep, Material) — save is blocked without it
- [x] Batch units ≥ 1 is enforced (CostingEngine division guard + form validation)
- [x] Bulk quantity ≥ 1 is enforced (same pattern)
- [x] Minutes and seconds fields clamp to 0–59 (not allowing 75 minutes)
- [x] Percentage fields accept reasonable ranges (0–100 display, 0–1 stored)
- [x] "Remove from Product" doesn't delete the shared entity — it's recoverable via "Add Existing"
- [x] Stopwatch discard option exists (don't overwrite good data with a bad timing run)
- [x] Stopwatch re-record option exists (start over without dismissing the view)
- [x] Delete confirmation dialogs clearly state consequences ("This step will be removed from all products")
- [x] Product duplication allows safe experimentation (try a price change on a copy)
- [ ] Category deletion warning explains products won't be deleted
- [x] Pricing calculator shows "fees too high" warning instead of displaying a negative/infinity target price
- [x] Shipping absorbed callout warns when the user may not realize they're eating shipping costs
- [x] Empty product state in Forecast tab directs user to Build tab (not a blank screen)
- [ ] No data loss on accidental sheet dismissal (iOS default swipe-to-dismiss behavior)

### Audit Result: 3/5

Calculation-side error prevention is strong: batch units and bulk quantity default to 1, minutes/seconds clamped, "fees too high" shows a clear warning, shipping absorbed callout exists. Remove-from-product is reversible. Stopwatch has discard and re-record options. Product duplication enables safe experimentation. Delete confirmations clearly explain consequences.

**Violations found:**

- **No data loss protection on sheet dismissal.** All form sheets (ProductFormView, WorkStepFormView, MaterialFormView) can be swiped away accidentally, losing all entered data. No `.interactiveDismissDisabled()` and no "discard changes?" confirmation.
- **Category deletion has no confirmation and no warning.** Swipe-to-delete on categories in CategoryListView and ProductFormView is immediate — no dialog explaining that products will become uncategorized but won't be deleted.
- **"Fees too high" gives no guidance.** The warning says "— (fees too high)" but doesn't explain how to fix it (reduce fee percentages, lower profit margin, etc.). The user is told something is wrong but not what to do about it.
- **Negative values silently corrected.** MaterialFormView converts negative costs to 0 and zero quantities to 1 without any user-visible feedback. The user enters "-5" and sees "0" appear with no explanation.

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

**Specific checks:**
- [ ] All tappable elements have accessibility labels (not just system-provided defaults)
- [ ] Images have appropriate accessibility traits (decorative images are hidden, meaningful images are labeled)
- [ ] Custom components (hero cards, proportional bars, stacked bars) have VoiceOver descriptions
- [ ] Stopwatch state is announced via VoiceOver ("Timer running: 2 minutes 30 seconds")
- [x] Dynamic Type support: text scales with system font size settings
- [ ] Hero values don't clip or overlap at largest Dynamic Type sizes
- [x] Color is never the only indicator (green/red profit also has +/- prefix or explicit label)
- [ ] Touch targets meet minimum 44x44pt guideline
- [x] Swipe actions (delete, duplicate) are also available via context menu (long press) for motor accessibility
- [ ] Platform locked fee labels include context for screen readers ("Etsy platform fee, 6.5 percent, set by platform")
- [ ] Keyboard navigation works for users with external keyboards
- [ ] Reduce Motion is respected (no essential animations that can't be disabled)

### Audit Result: 1/5

The app has effectively no accessibility consideration in its design. Only 4 accessibility labels exist in the entire codebase. VoiceOver would be unusable for custom components. This matches the code quality rubric finding — the gap is at both the design and implementation level.

**Violations found:**

- **VoiceOver is unusable for custom components.** Only 4 `accessibilityLabel` instances exist. All custom buttons (reorder arrows, +/- batch, menu icons, chip filters) read as "Button" with no context. Hero value cards, proportional bars, stacked cost bars, and the stopwatch timer have no VoiceOver descriptions.
- **Touch targets below 44x44pt.** Reorder arrows, batch +/- buttons, plus-circle buttons, and category chips are all below the minimum guideline.
- **No Reduce Motion support.** Reorder toggle animation and stopwatch numeric text transition ignore `accessibilityReduceMotion`.
- **Stopwatch not announced.** Timer state changes (start, pause, resume) post no accessibility notifications. Running time has no `accessibilityValue`.
- **Locked fee context missing for screen readers.** Lock icon label says "Locked by platform" — should say which platform and why.

**Partial passes:** Color is never the sole indicator (numbers always accompany green/red). Most typography uses scalable text styles. Swipe actions are also available via context menu (long press).

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

**Specific checks:**
- [x] Tab bar uses SF Symbols matching Apple's visual style
- [x] Navigation uses NavigationStack (not custom back button implementations)
- [x] Sheets are used for creation/editing (modal); push is used for drill-down (non-modal)
- [x] Toolbar items follow iOS convention: primary actions trailing, secondary leading
- [x] Picker controls use system styles (segmented, menu, wheel) where appropriate
- [x] Form layout follows iOS standards (grouped sections with headers and footers)
- [ ] Pull-to-dismiss works on all sheets
- [x] Swipe-back gesture works in all NavigationStack contexts
- [x] System color scheme (light/dark) is respected; custom appearance applies via `.preferredColorScheme()`
- [x] Text selection and copy work on value display fields
- [x] Context menus (long press) follow iOS conventions
- [x] fullScreenCover is used appropriately (stopwatch = immersive task, not a detail view)
- [x] SF Symbols are used throughout (not custom icon assets)
- [x] Search bar follows iOS conventions (.searchable modifier, correct placement)
- [x] Safe areas are respected on all device sizes (no content hidden behind Dynamic Island, home indicator)

### Audit Result: 4/5

The app feels native. All tabs use NavigationStack (zero NavigationView). SF Symbols throughout. Standard system controls (Picker, TextField, Form, PhotosPicker). Sheet vs push pattern is perfectly consistent. fullScreenCover used only for the stopwatch (appropriately immersive). Safe areas properly respected. Search bars follow iOS conventions with `.searchable` modifier. Context menus use standard long-press. System color scheme respected via `.preferredColorScheme()`.

**Violations found:**

- **No unsaved data protection on sheets.** HIG recommends that sheets with user-entered data should either prevent accidental dismissal or show a confirmation dialog. All form sheets allow pull-to-dismiss with immediate data loss.
- **Duplicate action is context-menu-only.** Product duplication is only accessible via long-press context menu — not exposed in toolbar, swipe actions, or any visible UI. A user who doesn't know about long-press will never discover this feature.
- **First-run doesn't prominently offer templates.** The empty-state ProductListView mentions templates in text but the actual template picker is nested inside the "+" Menu dropdown. For a first-run experience, HIG would suggest a more prominent CTA.

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

**Specific checks:**
- [x] ProductDetailView sub-tabs effectively separate Build (what it costs), Price (what to charge), Forecast (batch planning)
- [x] Pricing calculator separates "Target Price Calculator" from "Profit Analysis" into distinct GroupBoxes
- [x] Zero-value fee rows are hidden in profit analysis breakdown (not showing "$0.00" clutter)
- [x] Revenue forecast section is hidden when no actual pricing exists (not showing empty/zero state)
- [x] Batch forecast shows one input (batch size) and derives everything — no configuration overload
- [x] Portfolio sort picker lets users focus on one metric at a time (not a dashboard of everything)
- [x] Locked fees are displayed but not editable — reduces decision count on Etsy/Shopify/Amazon tabs
- [x] Material buffer and labor buffer are inline within their respective sections (not a separate settings page)
- [x] Cost summary card shows 3–4 lines max (labor, materials, shipping, total) — not every sub-cost
- [x] Shopping list groups per-material info clearly (units needed, purchase recommendation, leftover) without cross-referencing
- [x] "Needs attention" callout in portfolio surfaces the single most important action item
- [x] Empty states guide the user to the next logical step (not just "nothing here")
- [x] Forms present fields in the order they'll naturally be filled (title first, derived values last)

### Audit Result: 4/5

Cognitive load management is one of the app's strongest areas. The Build/Price/Forecast sub-tabs effectively separate three distinct questions. The pricing calculator cleanly divides "what should I charge?" from "what am I actually making?" with a visual separator. Zero-value fee rows are hidden in the profit breakdown. Revenue forecast is hidden when no pricing exists. Batch forecast's single-input-drives-everything design is immediately clear. Portfolio sort lets users focus on one metric at a time. Sections are collapsible via DisclosureGroup. Shopping list groups information per-material without cross-referencing.

**Violations found:**

- **PricingCalculatorView is dense after scrolling.** 12+ input fields and 20+ display rows across two calculator sections. No way to collapse the Target Price Calculator section when the user is focused on Profit Analysis. No "summary mode" to reduce visual noise.
- **Portfolio requires tab switching to compare.** To compare earnings AND hourly rate AND margin, the user must switch tabs three times. No consolidated mini-view for quick cross-metric comparison.

---

## Scoring Summary Template

| # | Dimension | Score (1-5) | Key Issue |
|---|-----------|-------------|-----------|
| 1 | Information Architecture & Navigation | **3** | "Used By" products not tappable; stopwatch 5 taps deep |
| 2 | Onboarding & First-Run Experience | **3** | Templates buried in sub-menu; no "aha moment" on Price tab |
| 3 | Form Design & Data Entry | **3** | No swipe-to-dismiss protection; silent validation |
| 4 | Visual Hierarchy & Typography | **4** | ProductCostSummaryCard uses plain GroupBox; picker style mismatch |
| 5 | Consistency & Patterns | **4** | Platform picker differs (.segmented vs .menu); toolbar structure varies |
| 6 | Labeling, Copy & Terminology | **3** | "Margin After Costs" ambiguous; "Effective Hourly Rate" is jargon |
| 7 | Feedback & Affordances | **3** | Category delete has no confirmation; duplication has no feedback |
| 8 | Data Visualization & Comprehension | **3** | Hardcoded "$0" breaks EUR; portfolio bars degrade at extremes |
| 9 | Error Prevention & Recovery | **3** | No data loss protection on forms; no "fees too high" guidance |
| 10 | Accessibility & Inclusivity | **1** | Effectively no implementation; VoiceOver unusable |
| 11 | Platform Conventions (iOS HIG) | **4** | No unsaved data protection on sheets; duplicate is hidden |
| 12 | Cognitive Load & Decision Complexity | **4** | PricingCalculatorView dense with 12+ fields; no collapse option |
| | **Total** | **38/60** | |

**Rating: Solid foundation, targeted improvements before launch** (36–44 range)

**Audit date:** 2026-04-04

**Rating scale:**
- 54–60: Exceptional UX — ship with confidence
- 45–53: Strong UX with minor polish needed
- 36–44: Solid foundation, targeted improvements before launch
- 24–35: Usable but significant friction — address before public release
- < 24: Fundamental UX issues — requires redesign before beta

---

## Top 3 Actions to Raise Score

1. **Accessibility (1 → 3 = +2 points).** Add accessibility labels to all buttons and hero values, fix touch targets to 44x44pt, add VoiceOver descriptions to custom components (stopwatch, portfolio bars), and check `reduceMotion`. This is the single largest score drag and the highest App Store rejection risk.

2. **Form data preservation (affects dims 3, 9, 11 = +1-2 points).** Add `.interactiveDismissDisabled()` to all form sheets when data has been entered. Add a "Discard changes?" confirmation on dismiss. This is the most common source of user frustration in any form-heavy app.

3. **Cross-reference navigation + pricing terminology (affects dims 1, 6 = +1-2 points).** Make "Used By" products tappable NavigationLinks. Rename "Margin After Costs" → "Profit Before Labor", "Effective Hourly Rate" → "Your Hourly Pay", and "Production Costs" → "Cost Breakdown". Fix the hardcoded "$0" to use CurrencyFormatter.
