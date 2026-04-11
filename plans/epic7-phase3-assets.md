# Epic 7 — Phase 3: Assets & Content

> **Parent:** [epic7-production-launch.md](epic7-production-launch.md)
> **Goal:** Produce every piece of non-code content that submission requires: landing page, legal docs, screenshots, app icon, App Store metadata, Privacy Nutrition Labels, review notes.

**Runs in parallel with [Phase 2 (engineering)](epic7-phase2-engineering.md).** Different work modes, different tools, different people (if you had more than one). Can start the moment Phase 1's gate passes.

**Status:** Planned.
**Estimated duration:** ~2 weeks (parallel with Phase 2).

---

## Phase Goal

By the end of Phase 3, everything a reviewer sees outside the app binary should be ready:
- Landing page live at the registered domain with full content (not the placeholder from Phase 1)
- Privacy Policy live at `/privacy` (GDPR-compliant)
- Terms of Use live at `/terms` (or Apple's standard EULA referenced)
- Support email active and monitored
- Template image provenance audit complete and archived
- App icon at 1024×1024 + dark variant + tinted variant for iOS 26
- Screenshots captured, annotated, and ready to upload (6–8 for 6.9" iPhone)
- App Store Connect metadata drafted: name, subtitle, description, keywords, categories, age rating, URLs, copyright
- Privacy Nutrition Labels filled in App Store Connect
- App Review notes drafted with the 60-second path
- DSA Trader Status complete both in ASC and on the landing page footer
- DPAs signed with PostHog, Sentry, RevenueCat

---

## 3.1 Marketing Landing Page (Full Build)

The placeholder from Phase 1 becomes a real landing page.

### Page Structure
- [ ] **Hero section:** headline, subheadline, App Store badge (official badges at [developer.apple.com/app-store/marketing/guidelines](https://developer.apple.com/app-store/marketing/guidelines/)), one hero screenshot (same as App Store screenshot #1)
- [ ] **Problem statement:** "Most makers underprice their work. Here's why." — 2–3 sentences on the pain point
- [ ] **Features section:** 3–6 short feature bullets with small screenshots (stopwatch, pricing calculator, portfolio, templates)
- [ ] **Pricing section:** Free tier summary + Pro (Annual $19.99 / Lifetime $49.99) with "Try free for 14 days" CTA leading to App Store
- [ ] **Footer links:**
  - Privacy Policy (`/privacy`)
  - Terms of Use (`/terms`)
  - Support email (`support@makermargins.com`)
  - **LLC legal info** (name, address, contact) — **REQUIRED by EU DSA** for the trader's own website, not just the App Store listing

### Hosting
- Domain + placeholder were set up in Phase 1
- Recommended: **Carrd Pro** ($19/yr) — designed for single-page sites, 1–2 hours of drag-and-drop for a finished site
- Alternative: GitHub Pages (free, HTML/CSS by hand)

---

## 3.2 Privacy Policy (GDPR-Compliant)

**New file on landing page:** `/privacy`

Because the app collects no personal data (SwiftData is local-only, analytics is fully anonymous), the GDPR exposure is genuinely minimal. The Privacy Policy still needs specific GDPR-required content:

- [ ] **Data controller identification:** LLC legal name, registered address, contact email
- [ ] **What data is processed:** anonymous diagnostics via Sentry, anonymous usage via PostHog, purchase history via RevenueCat (all Not Linked to User)
- [ ] **Lawful basis:** legitimate interests — debugging and product improvement
- [ ] **User rights under GDPR:** access, rectification, erasure, objection, portability. Most are N/A because nothing is linked to users, but the rights must still be documented.
- [ ] **Product data statement:** "No product data (costs, products, labor times, supplier details) ever leaves the device."
- [ ] **Data retention policy:** PostHog and Sentry default retentions (typically 90 days to 1 year) must be documented
- [ ] **Processors list:** PostHog, Sentry, RevenueCat by name with links to their DPAs
- [ ] **Cookie banner:** not needed (no web tracking, only mobile app)
- [ ] **Contact email for privacy inquiries:** `support@makermargins.com` or dedicated `privacy@makermargins.com`

### Privacy Nutrition Label Match
The Privacy Policy content **must match** the Privacy Nutrition Label (section 3.8). If ASC declares "we don't collect X" and the Privacy Policy says we do, it's a rejection.

---

## 3.3 Terms of Use / EULA

**New file on landing page:** `/terms`

- [ ] Use Apple's standard EULA text verbatim (publicly licensed) OR a custom version
- [ ] Apple's standard EULA covers subscriptions, so no additional subscription-specific language needed
- [ ] Hosted URL must be added to:
  - App Store Connect → App Information → End User License Agreement (if custom)
  - Paywall (Terms of Use link)
  - Settings (Terms of Use link)
  - Landing page footer

---

## 3.4 Support Email

- [ ] Activate `support@makermargins.com` at the registered domain
- [ ] **Hosting options:**
  - **Cloudflare Email Routing** (free, forwards to personal Gmail/Outlook) — cheapest, recommended
  - **Google Workspace** ($6/mo/user) if already used for the LLC
  - **Fastmail / Proton Mail** (~$3–5/mo) for independent providers
- [ ] **MUST be monitored** — Apple Review sometimes tests it. Multi-hour response times can stall review.
- [ ] Use as the contact for: Privacy Policy, Terms of Use, App Store Support URL, App Store Connect App Review contact info, beta tester feedback

---

## 3.5 Data Processing Agreements (DPAs)

Required for GDPR compliance when using EU-facing processors. Each vendor offers a free DPA through their dashboard.

- [ ] **PostHog DPA** — sign in their dashboard, archive the PDF
- [ ] **Sentry DPA** — sign in their dashboard, archive the PDF
- [ ] **RevenueCat DPA** — sign in their dashboard, archive the PDF
- [ ] Store all three signed copies in the LLC's legal document folder

---

## 3.6 Template Image Provenance — Complete Audit

This was started in Phase 1 but finalize it here before submission.

- [ ] Complete [plans/asset-provenance.md](asset-provenance.md) with all 42 template image sets documented
- [ ] Replace any images with unclear provenance
- [ ] Archive the final document with license receipts for any commercial stock

---

## 3.7 App Icon

### Master Icon
- [ ] **1024 × 1024 px App Store marketing icon** in `Assets.xcassets`
  - PNG format
  - No transparency, no alpha channel
  - No rounded corners (iOS applies the rounded-rect mask automatically)
  - Readable at smallest size (Settings icon, 29pt)

### iOS 26 Required Variants
- [ ] **Dark mode variant** — alternate rendering for dark appearance
- [ ] **Tinted variant** — monochrome version used when user enables tinted icon mode in iOS 26

### All iPhone Sizes
- [ ] Populate all required iPhone icon sizes in `Assets.xcassets` (Xcode generates most from the 1024 master, but verify all slots are filled)

---

## 3.8 Screenshots

### Required Size
- [ ] **6.9" iPhone** (iPhone 16 Pro Max / 17 Pro Max) — **1320 × 2868 px portrait**
- iPad screenshots skipped per resolved scope (iPad deferred to v1.1+)

### Count
- [ ] Minimum 3, maximum 10. **Target: 6–8** for a complete story without padding.

### Recommended Sequence
1. [ ] **Hero / Value proposition** — Portfolio view with 3+ products showing "Your Earnings / Sale" and "Your Hourly Pay." This is the wow moment.
2. [ ] **The math working** — Pricing Calculator with Etsy tab visible, showing target price + profit analysis
3. [ ] **Labor tracking** — Stopwatch mid-use or WorkStep detail with recorded time
4. [ ] **Materials ledger** — Material detail view with bulk cost / unit cost breakdown
5. [ ] **Templates** — TemplatePickerView showing the 5 workflows (communicates "start in 60 seconds")
6. [ ] **Batch forecasting** — BatchForecastView with shopping list
7. [ ] **(Optional) Cross-platform comparison** — Pricing Calculator with multiple platform tabs visible (Pro upsell communication)
8. [ ] **(Optional) Settings / polish** — showcases Liquid Glass design

### Production Notes
- [ ] Use **real-looking data**, not Lorem Ipsum. Authentic product names (e.g. "Walnut Cutting Board," "Soy Candle 8oz," "Leather Wallet," "Ceramic Mug")
- [ ] Capture from simulator at exact required resolution using `xcrun simctl io booted screenshot` on the Mac CI runner
- [ ] PNG or JPEG, RGB, no alpha channel, no transparency
- [ ] Status bar: full battery, full signal (simulator handles this)
- [ ] No device frames in the screenshots themselves — Apple adds frames on the store

### Annotations
- [ ] **Annotate 2–3 screenshots** with short callout labels (e.g. "Stopwatch tracks real labor," "See which products actually make you money") — industry standard, proven to increase conversions
- [ ] **Tool options:**
  - Raw simulator screenshots with annotations in Figma / Sketch / Pixelmator (most control)
  - Screenshot Studio / Rotato / Picasso / AppLaunchpad (paid, fastest)
  - Fastlane Snapshot (overkill for single-language indie launch)

### App Preview Video
- [ ] **Skip for 1.0** unless polished footage already exists. Screenshots alone convert fine for utility apps. Revisit post-launch.

---

## 3.9 App Store Connect Metadata

Fill in App Store Connect → App Information and the version entry.

### Text Fields (English-US)
- [ ] **App name** (30 chars max): `MakerMargins`
- [ ] **Subtitle** (30 chars max): e.g. "True Cost & Pricing for Makers"
- [ ] **Promotional text** (170 chars, editable without resubmission): use for timely messaging
- [ ] **Description** (4000 chars max): long-form sales copy
  - Lead with the problem ("Stop underpricing your handmade work")
  - Explain the solution
  - Feature bullets
  - Free tier + Pro upgrade mention
- [ ] **Keywords** (100 chars, comma-separated, no spaces after commas): `etsy,shopify,pricing,cogs,handmade,craft,woodworking,maker,cost,profit,wholesale,inventory`
- [ ] **Support URL**: your landing page (or `/support` subpage)
- [ ] **Marketing URL**: landing page root (optional but recommended)
- [ ] **Copyright**: `© 2026 [LLC Legal Name]`

### Classification
- [ ] **Primary category**: Business
- [ ] **Secondary category**: Productivity
- [ ] **Age rating questionnaire** → resolves to **4+**
- [ ] **Content rights declaration** — confirm owning or licensing all content (relies on [plans/asset-provenance.md](asset-provenance.md))

### Availability
- [ ] **US and European storefronts** selected (per resolved scope)
- [ ] Pricing tiers: let Apple auto-fill EU equivalents from $19.99 / $49.99 base; adjust only if rounding feels off

---

## 3.10 Privacy Nutrition Labels

Fill in App Store Connect → App Privacy. Expected state:

| Category | Type | Linked to User | Tracking | Purpose |
|---|---|---|---|---|
| Diagnostics | Crash Data | **No** | **No** | App Functionality |
| Diagnostics | Performance Data | **No** | **No** | App Functionality |
| Usage Data | Product Interaction | **No** | **No** | Analytics |
| Purchases | Purchase History | **No** | **No** | App Functionality |

- [ ] **No data "Linked to You"**
- [ ] **No "Tracking"**
- [ ] **No ATT prompt required** (confirmed by vendor configuration in Phase 2)
- [ ] **Privacy Policy URL** linked in ASC → App Privacy

---

## 3.11 App Review Information

Fill in App Store Connect → App Review Information.

### Contact
- [ ] **Name, phone, email** for the App Review team to reach you

### Demo Account
- [ ] **None needed** — MakerMargins has no login. Note this explicitly in the demo account instructions field so reviewers don't expect credentials.

### Notes for the Reviewer (CRITICAL)
Include the full 60-second path + context:

```
The app has no login. Functionality is immediately available on launch.

A 14-day free trial starts on first launch (managed by RevenueCat / StoreKit).
No payment card required during trial.

=== Reviewer's 60-Second Path ===
1. Launch the app — trial status is visible in Settings ("14 days of Pro unlocked")
2. Empty Products tab shows a prominent "Start from Template" CTA
3. Tap the CTA, pick any template (e.g. "Candles")
4. The app auto-navigates to the new Product's Build tab with pre-populated
   steps and materials and a live cost breakdown
5. Tap the Price tab — Pricing Calculator with General + Etsy tabs, showing
   target price and profit analysis
6. Tap Portfolio (via the Products tab) — see the product in the Portfolio view

=== Pro Features ===
- Unlimited products (free tier limited to 3)
- Shopify and Amazon platform tabs in the Pricing Calculator (free has General + Etsy)
- These Pro features are unlocked automatically during the 14-day trial.

=== To Test Post-Trial Gating ===
Use a sandbox account that has already consumed the trial intro offer. The
paywall will then show annual pricing without the "14-day free trial" badge
(we handle this consumed-trial case dynamically).

=== Non-Obvious Flows ===
- Stopwatch: Labor tab → tap any step → timer icon in toolbar → StopwatchView
- Templates create shared WorkSteps and Materials that are reusable across products

=== Privacy ===
The app does not collect or transmit any user-entered data (product titles,
costs, labor times, supplier info). Analytics (PostHog) and crash reporting
(Sentry) are fully anonymous with no PII, no IDFA, no user identification.
Analytics can be disabled in Settings → Privacy.
```

### Attachment (Recommended)
- [ ] **Screen recording** — short video (~30 seconds) demonstrating install → apply template → see cost breakdown → open paywall. Substantially reduces rejection risk for subscription apps.

---

## 3.12 DSA Trader Status — Finalization

Phase 1 filled out DSA Trader Status in App Store Connect. Phase 3 ensures the same info appears on the landing page.

- [ ] **Landing page footer** includes:
  - LLC legal name
  - Registered business address
  - Phone number
  - Email address
  - Trade register number (state registration or EIN)
- [ ] This can be a simple footer block or a dedicated `/impressum` page (German convention but works worldwide)

---

## Phase 3 Completion Gate

Phase 4 requires all of these to be done:

- [ ] ✅ Landing page live with all sections (hero, problem, features, pricing, footer with LLC trader info)
- [ ] ✅ Privacy Policy live at `/privacy` with GDPR-compliant content
- [ ] ✅ Terms of Use live at `/terms` (or Apple standard EULA)
- [ ] ✅ `support@makermargins.com` active and monitored
- [ ] ✅ DPAs signed with PostHog, Sentry, RevenueCat (archived)
- [ ] ✅ [plans/asset-provenance.md](asset-provenance.md) complete with all 42 template images documented
- [ ] ✅ App icon: 1024×1024 master + dark variant + tinted variant + all sizes in `Assets.xcassets`
- [ ] ✅ 6–8 screenshots captured, annotated, ready to upload
- [ ] ✅ App Store Connect metadata drafted: name, subtitle, promo text, description, keywords, support URL, marketing URL, categories, age rating, copyright
- [ ] ✅ Privacy Nutrition Labels filled in ASC matching the expected state
- [ ] ✅ App Review notes drafted with the 60-second path
- [ ] ✅ Optional: screen recording of activation flow for reviewer attachment
- [ ] ✅ DSA Trader Status filled in ASC (Phase 1) AND mirrored on landing page footer

---

## Files Touched in Phase 3

**Code:** none (this phase is content, not code).

**External / Plans:**
- Landing page content (hosted on Carrd or similar)
- `/privacy` subpage content
- `/terms` subpage content
- `support@makermargins.com` email configured
- [plans/asset-provenance.md](asset-provenance.md) — completed
- `Assets.xcassets/AppIcon` — dark and tinted variants added
- Screenshot PNG files — saved locally, ready to upload to ASC
- Screen recording video — optional, saved locally
- App Store Connect metadata fields — filled via ASC web UI
- Privacy Nutrition Labels in ASC — filled via web UI
- App Review Information in ASC — filled via web UI
- DPA PDFs — archived from vendor dashboards
