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
- [ ] Product detail view sub-tabs (Build/Price/Forecast) are discoverable without instruction
- [ ] Shared entities are accessible from both their library tab AND from within product detail
- [ ] "Used By" sections show where an item is linked without requiring navigation
- [ ] Portfolio view is discoverable from the Products tab (toolbar icon is recognizable)
- [ ] Back navigation is always available and returns to the expected screen
- [ ] Sheet vs push navigation is used appropriately (sheets for creation/editing, push for drill-down)
- [ ] The user is never more than 3 taps from the tab root
- [ ] Navigation after item creation takes the user to the right place (auto-navigate to detail)
- [ ] Tab badge or visual cue indicates which tab the user is on

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
- [ ] Every list view (Products, Labor, Materials) has a meaningful empty state with action guidance
- [ ] Template picker is offered prominently (not buried in a sub-menu)
- [ ] Template picker shows what each template includes (not just a name)
- [ ] Templates have bundled images (populated product looks "real" immediately)
- [ ] After applying a template, the user lands on the product detail with all data visible
- [ ] Template products have realistic actual prices set so profit analysis works immediately
- [ ] Settings defaults (labor rate, currency) are reasonable for a first-time user
- [ ] No required setup step before the user can start creating (no mandatory onboarding flow)
- [ ] The "+ menu" (Blank Product / From Template) is obvious and easy to tap

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
- [ ] All monetary fields use decimal keyboard (`.decimalPad`)
- [ ] All integer quantity fields use number keyboard (`.numberPad`)
- [ ] Time fields (h/m/s) clamp to valid ranges (0–59 for minutes/seconds)
- [ ] Required fields have clear validation feedback (not just a silent save failure)
- [ ] Default values (1 for quantities, 0 for costs) prevent division-by-zero without user action
- [ ] Focus-clear-on-tap behavior works for percentage and currency fields (clear "0" on focus, restore on blur if empty)
- [ ] Real-time calculated previews show derived values (Hours/Unit, Cost/Unit) as the user fills fields
- [ ] Photo picker provides Add/Change/Remove options (not just Add)
- [ ] Category creation is inline from the product form (no navigation to a separate screen)
- [ ] Save button is disabled when required fields are empty (not enabled with a post-tap error)
- [ ] Form preserves entered data if the user accidentally swipes to dismiss
- [ ] Long text fields (description) allow multi-line input with appropriate height
- [ ] Percentage fields display whole numbers (30) but store fractions (0.30) — no user confusion

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
- [ ] Hero values (target price, earnings/sale, total production cost) use large bold accent typography
- [ ] Derived/calculated values use accent color to distinguish from user-entered values
- [ ] Section headers are visually consistent across all views (same font weight, size, icon style)
- [ ] Labels use secondary/tertiary foreground — never competing with values for attention
- [ ] Positive profit is green, negative profit is red — universally applied
- [ ] Pricing calculator sections have visual separation from product-building sections (pricingSurface)
- [ ] Card elevation creates clear containment (surfaceElevated over surface background)
- [ ] Cost summary card hierarchy: individual costs → subtotals → total (increasing visual weight)
- [ ] Font sizes follow a consistent scale (not arbitrary sizes like 13, 15, 17, 19)
- [ ] Monospaced font is used only for the stopwatch timer display (not elsewhere)
- [ ] GroupBox headers clearly indicate collapsible/expandable sections
- [ ] Sufficient spacing between sections — content doesn't feel "stacked" without rhythm

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
- [ ] WorkStep and Material flows are structurally parallel (list, detail, form, library — same patterns)
- [ ] All searchable lists use the same search behavior (in-memory, real-time, same placement)
- [ ] All delete confirmations use the same dialog style and language pattern
- [ ] Context menu actions are consistent (same actions available in same contexts)
- [ ] "Add New" and "Add Existing" follow the same multi-select picker pattern for both steps and materials
- [ ] Reorder mode uses the same toggle + arrow button pattern for both steps and materials
- [ ] Hero card styling is identical across ProductCostSummaryCard, PricingCalculatorView, BatchForecastView, and PortfolioView
- [ ] Platform picker appearance and behavior is identical in PricingCalculator, BatchForecast, and Portfolio
- [ ] Library tab layout is parallel: Labor tab and Materials tab use the same row structure (thumbnail, title, usage, metric)
- [ ] "Remove from Product" button placement and styling is identical for both steps and materials
- [ ] Toolbar icon positions are predictable (edit on trailing, navigation on leading)
- [ ] All monetary values throughout the app pass through the same CurrencyFormatter (consistent decimal places, symbol placement)

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
- [ ] "Your Hourly Rate", "Your Earnings", "Your Hours" — solo-maker personal framing used consistently
- [ ] Dynamic unit labels: "Time per board", "Boards per Product" (not generic "units")
- [ ] "Time to Complete Batch" / "Units per Batch" — batch-oriented labels (not "Recorded Time")
- [ ] Buffer fields include helper text explaining what the percentage means
- [ ] Pricing section labels distinguish: "Production Cost" vs "Target Price" vs "Selling Price" vs "Earnings"
- [ ] Platform fee labels explain what they are: "Platform Fee (Etsy: 6.5%)" not just "6.5%"
- [ ] Locked fee display includes explanation: "Set by Etsy" or equivalent
- [ ] "Used by Standard Bagel Board + 2 others" — human-readable, not "Used by 3 products"
- [ ] Shopping list uses actionable language: "Buy 3 × 32 oz Soy Wax" not "96 oz required / 32 oz per bulk"
- [ ] Profit hero label says "Your Earnings / Sale" not "Net Profit" or "Gross Margin"
- [ ] "Margin After Costs" is clearly secondary to "Your Earnings" (not competing for attention)
- [ ] Empty state messages tell the user what to do, not just what's missing ("Add work steps to calculate labor costs" not "No work steps")
- [ ] No abbreviations that could confuse (hrs is ok, "prc" or "qty" are not)
- [ ] Tooltip/help text exists for non-obvious fields (% Sales from Ads, Material Buffer)

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
- [ ] "Remove from Product" is distinct from "Delete" — both in wording and visual treatment
- [ ] Editable fields have `.editableFieldStyle()` background to signal interactability
- [ ] Locked/read-only fee values use tertiary color — clearly non-interactive
- [ ] Stopwatch clearly shows its state: idle (Start visible), running (Pause visible), paused (Resume + Save visible)
- [ ] Real-time cost previews update as the user types (not on save)
- [ ] "Use Target Price" button is visible and clearly communicates its purpose
- [ ] Save/Cancel buttons on forms are consistently placed and labeled
- [ ] Successful template application results in visible navigation to the new product
- [ ] Product duplication gives feedback (new product appears in list, possibly with "(Copy)" suffix visible)
- [ ] Category filter chips show which filter is active (visual selection state)
- [ ] Sort picker in PortfolioView clearly shows the active sort metric
- [ ] List/grid toggle has clear visual state indicating the current mode
- [ ] Reorder mode toggle clearly indicates when reorder is active vs inactive

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
- [ ] Percentages display as whole numbers with % symbol (30%, not 0.30)
- [ ] Time displays use human-readable format where appropriate ("4h 30m" for batch totals, h:m:s for stopwatch)
- [ ] Hours/Unit uses precise decimal format (0.0833 hrs) for accuracy in costing context
- [ ] Portfolio bars are proportional to their values (longest bar = highest value, others scaled)
- [ ] Cost breakdown stacked bars clearly distinguish components (labor/material/shipping) with legend
- [ ] Green/red color coding for profit is universally applied and colorblind-accessible (not color alone)
- [ ] "Earnings / Sale" is immediately scannable without reading the breakdown
- [ ] Shopping list format is actionable: "Buy 3 × 32 oz" not "96 oz needed, 32 oz per bulk"
- [ ] Batch labor forecast shows both precise total (12.50 hrs) and readable format (12h 30m)
- [ ] Fee breakdown in pricing calculator shows individual fees AND total fees percentage
- [ ] Revenue forecast breakdown clearly shows the waterfall: revenue → fees → costs → profit
- [ ] PortfolioView summary card surfaces the single most important insight (top earner or needs attention)
- [ ] "N/A" is used instead of "$0.00" or "0%" when a metric is genuinely not applicable (e.g., hourly rate with no labor)

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
- [ ] Title is required on all create forms (Product, WorkStep, Material) — save is blocked without it
- [ ] Batch units >= 1 is enforced (CostingEngine division guard + form validation)
- [ ] Bulk quantity >= 1 is enforced (same pattern)
- [ ] Minutes and seconds fields clamp to 0–59 (not allowing 75 minutes)
- [ ] Percentage fields accept reasonable ranges (0–100 display, 0–1 stored)
- [ ] "Remove from Product" doesn't delete the shared entity — it's recoverable via "Add Existing"
- [ ] Stopwatch discard option exists (don't overwrite good data with a bad timing run)
- [ ] Stopwatch re-record option exists (start over without dismissing the view)
- [ ] Delete confirmation dialogs clearly state consequences ("This step will be removed from all products")
- [ ] Product duplication allows safe experimentation (try a price change on a copy)
- [ ] Category deletion warning explains products won't be deleted
- [ ] Pricing calculator shows "fees too high" warning instead of displaying a negative/infinity target price
- [ ] Shipping absorbed callout warns when the user may not realize they're eating shipping costs
- [ ] Empty product state in Forecast tab directs user to Build tab (not a blank screen)
- [ ] No data loss on accidental sheet dismissal (iOS default swipe-to-dismiss behavior)

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
- [ ] Dynamic Type support: text scales with system font size settings
- [ ] Hero values don't clip or overlap at largest Dynamic Type sizes
- [ ] Color is never the only indicator (green/red profit also has +/- prefix or explicit label)
- [ ] Touch targets meet minimum 44x44pt guideline
- [ ] Swipe actions (delete, duplicate) are also available via context menu (long press) for motor accessibility
- [ ] Platform locked fee labels include context for screen readers ("Etsy platform fee, 6.5 percent, set by platform")
- [ ] Keyboard navigation works for users with external keyboards
- [ ] Reduce Motion is respected (no essential animations that can't be disabled)

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
- [ ] Tab bar uses SF Symbols matching Apple's visual style
- [ ] Navigation uses NavigationStack (not custom back button implementations)
- [ ] Sheets are used for creation/editing (modal); push is used for drill-down (non-modal)
- [ ] Toolbar items follow iOS convention: primary actions trailing, secondary leading
- [ ] Picker controls use system styles (segmented, menu, wheel) where appropriate
- [ ] Form layout follows iOS standards (grouped sections with headers and footers)
- [ ] Pull-to-dismiss works on all sheets
- [ ] Swipe-back gesture works in all NavigationStack contexts
- [ ] System color scheme (light/dark) is respected; custom appearance applies via `.preferredColorScheme()`
- [ ] Text selection and copy work on value display fields
- [ ] Context menus (long press) follow iOS conventions
- [ ] fullScreenCover is used appropriately (stopwatch = immersive task, not a detail view)
- [ ] SF Symbols are used throughout (not custom icon assets)
- [ ] Search bar follows iOS conventions (.searchable modifier, correct placement)
- [ ] Safe areas are respected on all device sizes (no content hidden behind Dynamic Island, home indicator)

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
- [ ] ProductDetailView sub-tabs effectively separate Build (what it costs), Price (what to charge), Forecast (batch planning)
- [ ] Pricing calculator separates "Target Price Calculator" from "Profit Analysis" into distinct GroupBoxes
- [ ] Zero-value fee rows are hidden in profit analysis breakdown (not showing "$0.00" clutter)
- [ ] Revenue forecast section is hidden when no actual pricing exists (not showing empty/zero state)
- [ ] Batch forecast shows one input (batch size) and derives everything — no configuration overload
- [ ] Portfolio sort picker lets users focus on one metric at a time (not a dashboard of everything)
- [ ] Locked fees are displayed but not editable — reduces decision count on Etsy/Shopify/Amazon tabs
- [ ] Material buffer and labor buffer are inline within their respective sections (not a separate settings page)
- [ ] Cost summary card shows 3–4 lines max (labor, materials, shipping, total) — not every sub-cost
- [ ] Shopping list groups per-material info clearly (units needed, purchase recommendation, leftover) without cross-referencing
- [ ] "Needs attention" callout in portfolio surfaces the single most important action item
- [ ] Empty states guide the user to the next logical step (not just "nothing here")
- [ ] Forms present fields in the order they'll naturally be filled (title first, derived values last)

---

## Scoring Summary Template

| # | Dimension | Score (1-5) | Key Issue |
|---|-----------|-------------|-----------|
| 1 | Information Architecture & Navigation | | |
| 2 | Onboarding & First-Run Experience | | |
| 3 | Form Design & Data Entry | | |
| 4 | Visual Hierarchy & Typography | | |
| 5 | Consistency & Patterns | | |
| 6 | Labeling, Copy & Terminology | | |
| 7 | Feedback & Affordances | | |
| 8 | Data Visualization & Comprehension | | |
| 9 | Error Prevention & Recovery | | |
| 10 | Accessibility & Inclusivity | | |
| 11 | Platform Conventions (iOS HIG) | | |
| 12 | Cognitive Load & Decision Complexity | | |
| | **Total** | **/60** | |

**Rating scale:**
- 54–60: Exceptional UX — ship with confidence
- 45–53: Strong UX with minor polish needed
- 36–44: Solid foundation, targeted improvements before launch
- 24–35: Usable but significant friction — address before public release
- < 24: Fundamental UX issues — requires redesign before beta
