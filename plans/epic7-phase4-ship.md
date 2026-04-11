# Epic 7 — Phase 4: Ship

> **Parent:** [epic7-production-launch.md](epic7-production-launch.md)
> **Goal:** QA the feature-complete build, run TestFlight beta, verify crash-free baseline, submit for review, handle the review, and launch.

**Status:** Planned — starts after both Phase 2 and Phase 3 gates pass.
**Estimated duration:** ~2 weeks (including Apple Review time).

This is the **linear phase**. Do not parallelize. Each sub-phase depends on the previous.

---

## Phase Goal

MakerMargins 1.0 is live on the iOS App Store in US + European storefronts, with phased release enabled, Sentry and PostHog receiving production telemetry, and no showstopper crashes.

---

## Sub-Phase 4a — Pre-Submission QA Sweep

Feature-complete build is in your hands. Time to break it.

### 4a.1 Background Stopwatch Verification
**Why:** the stopwatch is a core feature for makers. If it stops when the app backgrounds or the device locks, it's useless.

**Expected pattern:** store a `Date` when the timer starts; compute elapsed time on display refresh as `Date.now.timeIntervalSince(startDate)`. This survives backgrounding, device lock, and interruptions automatically. **Do not use `Timer.scheduledTimer` alone** — those can be suspended by the system.

**Test scenarios:**
- [ ] Start stopwatch → background the app for 2 minutes → foreground → verify elapsed is ~2 minutes, not frozen
- [ ] Start stopwatch → lock device for 2 minutes → unlock → verify elapsed correct
- [ ] Start stopwatch → receive a phone call → end call → verify elapsed correct
- [ ] Start stopwatch → force-quit the app → relaunch → expected behavior: session is lost (or persisted if that's the explicit design choice)
- [ ] Start stopwatch → low power mode → verify timer still accurate

**Fix if broken:** refactor to `Date`-based calculation. If broken, this is a blocking bug — do not ship until fixed.

### 4a.2 Empty & Error States Audit
Apple rejects apps with missing empty states, broken error paths, or crashes on edge cases. Reviewers deliberately test these.

**Empty states to verify:**
- [ ] `ProductListView` — empty state with "Start from Template" CTA
- [ ] `WorkshopView` — no work steps created yet
- [ ] `MaterialsLibraryView` — no materials created yet
- [ ] `PortfolioView` — no products priced yet
- [ ] `BatchForecastView` — product with no steps/materials, batch size 0
- [ ] `WorkStepDetailView` — "Used By" section with zero products
- [ ] `MaterialDetailView` — "Used By" section with zero products
- [ ] `ProductDetailView` Build tab — product with no steps or materials yet
- [ ] `PricingCalculatorView` — product with zero cost (no labor, no materials)
- [ ] Category list — no categories created
- [ ] Search results in Workshop/Materials tabs — no matches

**Error states to verify:**
- [ ] SwiftData save failure — wraps writes in do/catch, shows toast or alert, logs to Sentry
- [ ] PhotosPicker fails to load image — silent skip or user-facing error (explicit choice)
- [ ] RevenueCat offering fetch fails on paywall open — shows retry button, not blank paywall
- [ ] Purchase failure — shows specific error from RevenueCat, not generic
- [ ] Restore purchases with no history — friendly "nothing to restore" message, not silent fail
- [ ] Trial expiry during active use — graceful downgrade, doesn't crash mid-action

**Loading states to verify:**
- [ ] RevenueCat offerings initial fetch — skeleton or spinner, not flash of empty paywall
- [ ] Large image load in thumbnail views — placeholder, not blank
- [ ] Category fetch — unlikely to need loading state given local SwiftData speed, but verify

**Action:**
- [ ] Full QA pass across all views listed above, ideally on a real device
- [ ] Fix anything missing or broken
- [ ] Add test cases to the appropriate epic test files where automatable

### 4a.3 First-Run / Reviewer Experience Walkthrough
Simulate the reviewer's path exactly as documented in the App Review notes.

- [ ] Fresh install on a clean simulator (delete + reinstall)
- [ ] Launch → verify trial status indicator is visible in Settings
- [ ] Empty `ProductListView` → "Start from Template" CTA is prominent (not a small button)
- [ ] Tap CTA → `TemplatePickerView` opens
- [ ] Tap any template → auto-navigates to Build tab (not the edit form)
- [ ] Cost breakdown is visible and accurate
- [ ] Tap Price tab → Pricing Calculator with General + Etsy tabs works
- [ ] Tap Portfolio → the new product appears with cost data
- [ ] **Total time to "aha":** verify it's under 60 seconds
- [ ] **No modal interruptions** on first launch (no "Welcome" sheet, no "Please rate us," no "Allow notifications")
- [ ] **Paywall does NOT trigger** during this path — it should only trigger on creating a 4th product or tapping Shopify/Amazon

### 4a.4 Accessibility Audit (on real device, not simulator)
- [ ] **VoiceOver rotor sweep** — every screen navigable by swipe, every element has a label, groups are logical
- [ ] **Dynamic Type at XXXL** — no truncation, no overflow, all layouts adapt
- [ ] **Dynamic Type at smallest sizes** — no wasted space, still readable
- [ ] **Reduce Motion enabled** — all animations respect the setting
- [ ] **Increase Contrast** — text remains readable, borders visible
- [ ] **Differentiate Without Color** — profit/loss indicators use `signedProfitPrefix` (CLAUDE.md-verified); no other color-only signals
- [ ] **Bold Text** — no layout breakage
- [ ] **Dark Mode + Light Mode** — every screen in both
- [ ] **Tinted icon mode (iOS 26)** — icon renders correctly with monochrome variant
- [ ] **VoiceOver announcements for stopwatch state** — verify still working after Epic 7 changes
- [ ] **Hero values include context** — verify still working

**Device matrix:**
- [ ] iPhone 16 Pro or 17 Pro (primary 6.9" target)
- [ ] iPhone 13 mini or smaller (optional, confirms small-screen support)
- [ ] Must use **real device, not simulator** — VoiceOver behaves differently on hardware

### 4a.5 Crash-on-Launch Scenario Testing
Verify the defensive init from Phase 2 actually works under failure conditions.

- [ ] **No network:** airplane mode first install — must launch successfully; PostHog/Sentry/RevenueCat queue offline
- [ ] **Corrupt SwiftData store:** manually corrupt the store file in simulator — must fall back to in-memory and show empty state without crashing
- [ ] **Missing Secrets (dev build):** build with empty `Secrets.dev.xcconfig` — must launch; vendors silently don't connect
- [ ] **Expired provisioning profile:** not something to test manually, but ensure the production profile doesn't expire before launch date

### 4a.6 Privacy Audit (Grep + Manual)
- [ ] `grep` the codebase for every `analytics.signal(...)` call site
- [ ] Manually verify **no SwiftData field values** are passed as payload values
- [ ] Verify no `@Model` property strings are interpolated into signal payloads
- [ ] Verify `AppLogger` calls with user data use `.private` interpolation, not `.public`
- [ ] Check Sentry `beforeBreadcrumb` hook is active and scrubbing correctly
- [ ] Verify Privacy Nutrition Labels in ASC match what's actually being sent

### 4a.7 Performance Pass
- [ ] **Cold launch** time <400ms on iPhone 16 Pro (measure via Instruments or MetricKit)
- [ ] **List scrolling** smooth with 20+ products (create dummy data, test ProductListView and PortfolioView)
- [ ] **Image loading** in thumbnail views — no jank
- [ ] **Memory footprint** — no leaks during normal flows (Instruments → Leaks)
- [ ] **No hangs** under normal use

### 4a.8 HIG & Content Compliance Sweep
Quick manual check before submission:

- [ ] **No placeholder content, Lorem Ipsum, or TODO comments visible to users** — grep source for `TODO`, `FIXME`, `XXX`, `Lorem`, `test`, `placeholder`
- [ ] **No references to other platforms** in marketing text (grep `Android`, `Google Play`, `web version`, `web app`)
- [ ] **No mentions of "beta," "test," or "preview"** in the 1.0 submission copy or UI
- [ ] **All links in the app and metadata work** — manually click every URL
- [ ] **Subscription UX rules** on paywall: trial clearly labeled, length prominent, post-trial price visible before subscribe tap, Restore Purchases in Settings, user can manage/cancel subscription via system UI

---

## Sub-Phase 4b — Sandbox Purchase Flow Validation

Required by the Phase 4 → Epic Complete gate.

- [ ] **Fresh install → trial starts:** new sandbox account, first launch, verify `isPro == true` during trial, `trialDaysRemaining` displays correctly
- [ ] **Trial expiry → free tier:** sandbox accelerates trial time; verify `isPro` drops to false, 4th product blocked, Shopify/Amazon tabs locked
- [ ] **Purchase annual:** paywall → tap annual → StoreKit sheet → confirm → `isPro == true`, Settings shows "Annual — renews [date]", RevenueCat dashboard reflects the customer
- [ ] **Purchase lifetime:** new sandbox account, paywall → tap lifetime → confirm → `isPro == true`, Settings shows "Lifetime"
- [ ] **Refund flow:** request a sandbox refund, verify `isPro` drops to false after customer info refresh
- [ ] **Restore on second device:** clean install on second device with same Apple ID → Settings → Restore Purchases → `isPro == true`
- [ ] **Consumed trial paywall display:** sandbox account that has consumed the intro offer on another app → paywall shows annual price WITHOUT "14-day free trial" badge; purchase still works
- [ ] **Manage Subscription link:** Settings → Manage Subscription → opens system sheet successfully
- [ ] **Manual test:** tap Shopify tab during trial → works fine; force trial expiry → tap Shopify tab → paywall appears with `.platformLocked(.shopify)` reason

---

## Sub-Phase 4c — TestFlight Internal Build

- [ ] **Tag a release candidate** (e.g. `v1.0.0-rc1`) to trigger the CI release workflow from [epic7-phase1-foundation.md](epic7-phase1-foundation.md) task 1.14
- [ ] Verify GitHub Actions workflow runs successfully:
  - Certificates imported into temporary keychain
  - Provisioning profile installed
  - Production `Secrets.prod.xcconfig` written from GitHub secrets
  - `xcodebuild archive` succeeds
  - `xcodebuild -exportArchive` produces a signed `.ipa`
  - `xcrun altool --upload-app` uploads to App Store Connect
  - dSYMs uploaded to Sentry
  - Keychain cleaned up
- [ ] Wait for App Store Connect to process the build (typically 10–30 minutes)
- [ ] Add internal testers in TestFlight (yourself + any team members)
- [ ] Install on a real iOS device
- [ ] Smoke test the full app: create product from template, run stopwatch, add materials, check pricing, view portfolio, open paywall, purchase in sandbox

---

## Sub-Phase 4d — Solo Beta Testing

**Approach:** Developer is the sole beta tester, using the app with real woodworking business data (real products, labor times, material costs, pricing decisions). External beta recruitment deferred to post-launch (Epic 8).

- [ ] Install TestFlight build on personal iPhone
- [ ] **Use the app as your real costing tool** for at least 5 days:
  - Enter 3+ real products from your woodworking catalog
  - Run the stopwatch for real labor tracking on at least 2 steps
  - Enter real material costs with actual supplier prices
  - Use the Pricing Calculator to price products for Etsy (real listings)
  - Run Batch Forecasting for a real upcoming production run
  - Compare Portfolio view across your products
  - Exercise the paywall by hitting the 3-product cap and the Shopify/Amazon tab lock
- [ ] **Monitor Sentry** daily during the beta — triage any crashes immediately
- [ ] **Log any friction or bugs** as GitHub issues
- [ ] **Triage and fix** any issues; tag a new RC and upload again if needed
- [ ] After the app is stable for 2 days with no crashes and you trust it with your real business data, proceed to submission

---

## Sub-Phase 4e — Crash-Free Baseline Verification

**48-hour gate.**

- [ ] Sentry dashboard shows **zero unresolved crashes** in the 48 hours immediately before submission
- [ ] If a crash appears during the baseline window: fix it, tag a new RC, restart the 48-hour clock
- [ ] Any hangs or performance regressions flagged by MetricKit are reviewed; none are showstoppers

---

## Sub-Phase 4f — App Store Connect Final Check

Before hitting submit:

- [ ] **Build selected** — the uploaded, processed build is attached to the 1.0 version
- [ ] **Version Information complete** — all text fields from Phase 3 filled in
- [ ] **Screenshots uploaded** in the correct order
- [ ] **App icon 1024** uploaded to App Information
- [ ] **IAP products** (`mm_pro_annual`, `mm_pro_lifetime`) attached and "Ready to Submit"
- [ ] **Privacy Nutrition Labels** complete
- [ ] **Privacy Policy URL** live and accessible
- [ ] **Support URL** live and accessible
- [ ] **Age rating** complete (4+)
- [ ] **Categories** set (Business primary, Productivity secondary)
- [ ] **Availability** — US + European storefronts selected
- [ ] **Price tier** set correctly for the app itself (Free, since monetization is IAP)
- [ ] **App Review Information** complete: contact, demo account instructions, notes, optional screen recording attached
- [ ] **Version release** — set to **Manual Release** for 1.0 (coordinate launch messaging)
- [ ] **Phased Release for Automatic Updates** — ENABLED (7-day gradual rollout)
- [ ] **Content rights** declaration confirmed
- [ ] **Export compliance** — `ITSAppUsesNonExemptEncryption = NO` in Info.plist, no additional paperwork needed
- [ ] **DSA Trader Status** complete
- [ ] **Terms of Use URL** — either using Apple's standard EULA (no action) or custom URL provided

---

## Sub-Phase 4g — Submit for Review

- [ ] **Tag the final release** (e.g. `v1.0.0`) to trigger the CI release workflow
- [ ] Wait for build processing in App Store Connect (10–30 min)
- [ ] Select the new build for the 1.0 version
- [ ] Click **"Submit for Review"**
- [ ] Confirm IAP products are submitted alongside the binary

**Expected timeline:**
- Standard review: 24–48 hours
- **Subscription apps: 3–5 days** because IAPs and paywall get extra scrutiny
- Pad for one rejection cycle; don't assume first-try approval

---

## Sub-Phase 4h — Review Monitoring & Response

- [ ] **Check App Store Connect daily** for review status updates
- [ ] **Monitor email** for reviewer messages — notifications are unreliable
- [ ] **Respond to reviewer questions within hours, not days** — slow responses turn a 2-day review into a 2-week review
- [ ] **If rejected:**
  1. Read the rejection carefully (rejection reasons cite specific Guidelines)
  2. Understand the actual issue (not just the surface symptom)
  3. Fix the specific issue
  4. Reply in Resolution Center with explanation of the fix
  5. Upload a new build with incremented build number
  6. Resubmit

### Common Rejection Reasons (Proactive Mitigations)
- **Guideline 2.1 — App Completeness:** Prevented by 4a QA sweep and TestFlight beta
- **Guideline 3.1.2 — Subscription disclosure:** Prevented by Phase 2 paywall implementation + consumed-trial handling
- **Guideline 5.1.1 — Privacy Policy:** Prevented by Phase 3 privacy policy hosting
- **Guideline 4.0 — Design:** Non-issue given Liquid Glass / iOS 26 native patterns
- **Guideline 2.3.10 — Other platform mentions:** Prevented by 4a.8 content scrub
- **Guideline 3.1.1 — IAP bypass:** Prevented by never mentioning "subscribe on our website" anywhere in the app or metadata
- **Missing Restore Purchases:** Prevented by Phase 2 Settings implementation

---

## Sub-Phase 4i — Launch

- [ ] **On approval:** manually release the build in App Store Connect
- [ ] **Phased Release starts automatically** (1% → 2% → 5% → 10% → 20% → 50% → 100% over 7 days)
- [ ] **Monitor Sentry** for crashes in the first 24 hours — be ready to pause phased release if a P0 appears
- [ ] **Monitor PostHog** for installs, trial starts, activation funnel — verify real-world data shape matches what you tested
- [ ] **Monitor RevenueCat** for trial-start events — confirms the IAP pipeline is working in production
- [ ] **Update CLAUDE.md** with any architectural decisions or implementation notes worth persisting
- [ ] **Mark Epic 7 as Complete** in CLAUDE.md roadmap table

---

## Phase 4 Completion Gate — Epic 7 Complete

Epic 7 is complete when all of the following are true:

1. ✅ Solo beta has run ≥5 days with real business data (real products, labor, materials, pricing)
2. ✅ Sentry reports ≥48 consecutive hours crash-free before submission
3. ✅ All sandbox purchase flows verified end-to-end
4. ✅ Privacy audit complete: no PII in analytics, no user content in error reports, Privacy Nutrition Label matches reality
5. ✅ App Store Connect ready-for-review checklist is 100% green
6. ✅ Build has been **approved** by Apple Review
7. ✅ MakerMargins 1.0 is **available on the App Store** in US + European storefronts
8. ✅ Phased Release enabled (7-day rollout)
9. ✅ CLAUDE.md updated with any architectural decisions made during implementation
10. ✅ CLAUDE.md roadmap table shows Epic 7 as Complete

---

## Files Touched in Phase 4

**Code:** potentially bug fixes from QA sweep and beta feedback — ad-hoc, no pre-specified file list.

**External:**
- TestFlight builds uploaded via CI release workflow
- App Store Connect submission
- App Store live listing (eventually)
- CLAUDE.md roadmap table update

**Tests:** any new test cases added during the QA sweep to prevent regressions

---

## Post-Launch Handoff

Once Epic 7 is complete, [epic8-post-launch-operations.md](epic8-post-launch-operations.md) takes over. Everything beyond "the app is live" — monitoring dashboards, incident response, review responses, support workflow, update cadence, launch marketing, ongoing ASO, financial/LLC hygiene — lives there.
