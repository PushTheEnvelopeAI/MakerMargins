# Epic 7 — Phase 2: Engineering

> **Parent:** [epic7-production-launch.md](epic7-production-launch.md)
> **Goal:** Ship all the code that Epic 7 requires. Runs **in parallel** with [Phase 3 (assets)](epic7-phase3-assets.md).

**Status:** In Progress — Sub-phase 2a complete.
**Estimated duration:** ~2 weeks.

---

## Phase Goal

By the end of Phase 2, the MakerMargins codebase should have:
- All data models augmented with `remoteID`, `createdAt`, `updatedAt` for future cross-platform sync
- A writes-only repository layer enforcing those fields
- All vendor SDKs integrated: PostHog, Sentry, MetricKit, RevenueCat
- `AppLogger` facade wrapping OSLog with cross-platform semantics
- Defensive, ordered init in `MakerMarginsApp` that survives network/cert/store failures
- A functional paywall with dynamic trial eligibility handling
- Product count + platform tab gating for the free tier
- A Pro section and Privacy section in Settings
- Full analytics instrumentation at the specified sites
- All new tests written and passing

Phase 4 depends on all of this being feature-complete.

---

## Execution Order (Sub-Phases)

Execute in order — later sub-phases depend on earlier ones.

| Sub-Phase | Scope | Why It's In This Order |
|---|---|---|
| 2a | Data layer (models, repositories, AppLogger) | Everything else depends on models having `remoteID`/timestamps and repositories existing |
| 2b | Vendor SDK wiring (Sentry, MetricKit, PostHog, RevenueCat) | Managers must exist before views can use them |
| 2c | Monetization UI (PaywallView, gating, Settings Pro section) | Depends on EntitlementManager from 2b |
| 2d | Telemetry wiring (Settings Privacy section + instrumentation sites) | Depends on AnalyticsManager from 2b and PaywallView from 2c |
| 2e | Edge cases + conventions (consumed trial, localization scaffolding, CostingEngine banner) | Cleanup after main code lands |
| 2f | Tests | Written alongside each sub-phase, finalized at the end |

---

## Sub-Phase 2a — Data Layer

### 2a.1 Model Changes — All 8 `@Model` Classes

Add to each model:
```swift
var remoteID: UUID? = nil        // populated by future sync layer
var createdAt: Date = .now
var updatedAt: Date = .now
```

**Files:**
- [MakerMargins/Models/Product.swift](MakerMargins/Models/Product.swift)
- [MakerMargins/Models/Category.swift](MakerMargins/Models/Category.swift)
- [MakerMargins/Models/WorkStep.swift](MakerMargins/Models/WorkStep.swift)
- [MakerMargins/Models/ProductWorkStep.swift](MakerMargins/Models/ProductWorkStep.swift)
- [MakerMargins/Models/Material.swift](MakerMargins/Models/Material.swift)
- [MakerMargins/Models/ProductMaterial.swift](MakerMargins/Models/ProductMaterial.swift)
- [MakerMargins/Models/PlatformFeeProfile.swift](MakerMargins/Models/PlatformFeeProfile.swift)
- [MakerMargins/Models/ProductPricing.swift](MakerMargins/Models/ProductPricing.swift)

Update `Schema` version in [MakerMargins/MakerMarginsApp.swift](MakerMargins/MakerMarginsApp.swift). Since the app has no shipped users yet, no `VersionedSchema` migration is strictly required — additive fields with defaults work out of the box.

**Preserves existing rule:** SwiftData's `persistentModelID` remains the local primary key. `remoteID` is a separate nullable sync field. The CLAUDE.md rule "no explicit `id: UUID` property" still holds — `remoteID` is not an `id`, it's a sync field.

### 2a.2 AppLogger — OSLog Facade

**New file:** `MakerMargins/Engine/AppLogger.swift`

```swift
import os

enum AppLogger {
    static let costing   = Logger(subsystem: "com.makermargins.app", category: "costing")
    static let swiftData = Logger(subsystem: "com.makermargins.app", category: "swiftdata")
    static let storeKit  = Logger(subsystem: "com.makermargins.app", category: "storekit")
    static let ui        = Logger(subsystem: "com.makermargins.app", category: "ui")
    static let lifecycle = Logger(subsystem: "com.makermargins.app", category: "lifecycle")
    static let analytics = Logger(subsystem: "com.makermargins.app", category: "analytics")
}
```

**Facade semantics:** the API surface (`AppLogger.costing.error(...)`) is what matters. When Android arrives, `AppLogger.kt` uses Timber/Logcat with identical call sites. When web arrives, `appLogger.ts` uses console+Sentry.

**Privacy rules:**
- Never log SwiftData model content with `.public`. Titles, costs, summaries → `.private` (redacted in release).
- Errors: `.error` level with `.public` for error type, `.private` for user data.
- State transitions: `.info` level.
- Verbose traces: `.debug` level (stripped from release automatically).

### 2a.3 Repository Protocol Layer (Writes-Only)

Views currently use `@Query` and `modelContext` directly. **Keep `@Query` for reads.** Introduce a repository protocol layer for **writes and domain operations only**.

**New folder:** `MakerMargins/Repositories/`

**Four repositories:**

```swift
// ProductRepository.swift
protocol ProductRepository {
    func create(...) async throws -> Product
    func update(_ product: Product, ...) async throws
    func delete(_ product: Product) async throws
    func duplicate(_ product: Product) async throws -> Product
}

final class SwiftDataProductRepository: ProductRepository {
    private let modelContext: ModelContext
    init(modelContext: ModelContext) { self.modelContext = modelContext }
    // ... implementation, enforces updatedAt = .now on every write
}
```

**Files to create:**
- `MakerMargins/Repositories/ProductRepository.swift` (protocol + `SwiftDataProductRepository`)
- `MakerMargins/Repositories/WorkStepRepository.swift` (protocol + impl)
- `MakerMargins/Repositories/MaterialRepository.swift` (protocol + impl)
- `MakerMargins/Repositories/CategoryRepository.swift` (protocol + impl)

**Scope:** join models (`ProductWorkStep`, `ProductMaterial`) and pricing models (`ProductPricing`, `PlatformFeeProfile`) are managed through their parent repositories — no standalone repo needed.

**Convention:** every write path sets `updatedAt = .now`. Repositories enforce this; views call repositories instead of `modelContext.insert(...)` or `modelContext.delete(...)` directly.

### 2a.4 Update Views to Use Repositories for Writes

Audit all views for direct `modelContext` mutations and replace with repository calls. Reads stay on `@Query`.

**Likely files:**
- [MakerMargins/Views/Products/ProductListView.swift](MakerMargins/Views/Products/ProductListView.swift)
- [MakerMargins/Views/Products/ProductFormView.swift](MakerMargins/Views/Products/ProductFormView.swift)
- [MakerMargins/Views/Products/ProductDetailView.swift](MakerMargins/Views/Products/ProductDetailView.swift)
- [MakerMargins/Views/Workshop/WorkshopView.swift](MakerMargins/Views/Workshop/WorkshopView.swift)
- [MakerMargins/Views/Labor/WorkStepFormView.swift](MakerMargins/Views/Labor/WorkStepFormView.swift)
- [MakerMargins/Views/Labor/WorkStepDetailView.swift](MakerMargins/Views/Labor/WorkStepDetailView.swift)
- [MakerMargins/Views/Materials/MaterialsLibraryView.swift](MakerMargins/Views/Materials/MaterialsLibraryView.swift)
- [MakerMargins/Views/Materials/MaterialFormView.swift](MakerMargins/Views/Materials/MaterialFormView.swift)
- [MakerMargins/Views/Materials/MaterialDetailView.swift](MakerMargins/Views/Materials/MaterialDetailView.swift)
- [MakerMargins/Engine/TemplateApplier.swift](MakerMargins/Engine/TemplateApplier.swift) — also writes via `modelContext`, should go through repositories

Grep for `modelContext.insert`, `modelContext.delete`, `.modelContext` to find all write sites.

### 2a.5 Schema Canonical Document

**New file:** [plans/schema-canonical.md](schema-canonical.md)

A language-agnostic reference document describing every model, field, type, relationship, default value, and sync semantics. This is the contract that keeps Swift models, future Kotlin models, future TypeScript models, and the future Supabase Postgres schema in sync.

Single source of truth, updated whenever models change.

---

## Sub-Phase 2b — Vendor SDK Wiring

### 2b.1 SPM Dependencies in project.yml

Add via XcodeGen `project.yml`:
- `https://github.com/PostHog/posthog-ios` — product analytics
- `https://github.com/getsentry/sentry-cocoa` — error + crash reporting
- `https://github.com/RevenueCat/purchases-ios` — subscriptions

### 2b.2 ErrorReporter — Sentry

**New file:** `MakerMargins/Engine/ErrorReporter.swift`

```swift
import Sentry

enum ErrorReporter {
    static func start() throws {
        SentrySDK.start { options in
            options.dsn = Secrets.sentryDSN
            options.sendDefaultPii = false
            options.releaseName = "makermargins@\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")"
            // Scrub breadcrumbs to never contain SwiftData content
            options.beforeBreadcrumb = { breadcrumb in
                // Strip anything that could be PII or user data
                return breadcrumb
            }
        }
    }
}
```

- Privacy config: `sendDefaultPii = false`, scrub breadcrumbs of any field that might contain SwiftData content, no user identification
- Release tracking via `release` tag
- Breadcrumbs: log view transitions and major actions, never model content

### 2b.3 MetricsSubscriber — MetricKit

**New file:** `MakerMargins/Engine/MetricsSubscriber.swift`

Conforms to `MXMetricManagerSubscriber`:
- `didReceive payloads: [MXMetricPayload]` → logs CPU/hangs/memory via `AppLogger.lifecycle.info`
- `didReceive payloads: [MXDiagnosticPayload]` → forwards crash counts to PostHog as a `crashDetected` signal (no stack trace content, just count + exception type — full detail comes from Sentry)

### 2b.4 AnalyticsSignal Enum — Cross-Platform Event Contract

**New file:** `MakerMargins/Engine/AnalyticsSignal.swift`

```swift
enum AnalyticsSignal: String {
    // Lifecycle
    case appLaunched
    case firstLaunch

    // Activation funnel (the aha moment)
    case templateApplied           // payload: templateId
    case firstProductCreated
    case firstWorkStepCreated
    case firstMaterialCreated
    case firstStopwatchUsed
    case firstPricingCalculated
    case portfolioViewed

    // Feature usage
    case productCreated
    case productDuplicated
    case stopwatchCompleted        // payload: batchSize bucket
    case batchForecastUsed
    case platformTabViewed         // payload: platformType
    case settingsOpened
    case currencyChanged           // payload: usd/eur
    case appearanceChanged

    // Monetization funnel
    case paywallShown              // payload: reason
    case paywallDismissed
    case trialStarted
    case purchaseAttempted         // payload: productId
    case purchaseSucceeded         // payload: productId
    case purchaseFailed            // payload: errorCode
    case restorePurchases

    // Crash forwarding (MetricKit)
    case crashDetected             // payload: exceptionType

    // Error surfaces
    case errorEncountered          // payload: errorDomain only
}
```

**Strict payload rules:**
- Payload values are **enums, small integers, or bucketed ranges** — never free-form user input
- Product counts → buckets: `1`, `2-5`, `6-20`, `20+`
- Prices → excluded entirely or log-scale buckets
- Titles, summaries, supplier URLs, labor rates, material costs: **never sent, ever**

**Also create:** [plans/analytics-signals.md](analytics-signals.md) documenting this enum as the cross-platform event contract (same signal names for future Android + web).

### 2b.5 AnalyticsManager — PostHog Wrapper

**New file:** `MakerMargins/Engine/AnalyticsManager.swift`

```swift
import PostHog

@Observable
final class AnalyticsManager {
    private(set) var isEnabled: Bool

    init() {
        let config = PostHogConfig(apiKey: Secrets.posthogAPIKey, host: Secrets.posthogHost)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.sessionReplay = false
        PostHogSDK.shared.setup(config)

        self.isEnabled = UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? true
        syncOptState()
    }

    func signal(_ name: AnalyticsSignal, payload: [String: String] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(name.rawValue, properties: payload)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "analyticsEnabled")
        syncOptState()
    }

    private func syncOptState() {
        if isEnabled {
            PostHogSDK.shared.optIn()
        } else {
            PostHogSDK.shared.optOut()
        }
    }
}
```

- `EnvironmentKey` + `EnvironmentValues` extension for injection
- Persisted `isEnabled` in `UserDefaults`, defaults **ON**
- Opt-out default-on is correct because PostHog with no PII doesn't require a GDPR consent dialog

### 2b.6 EntitlementManager — RevenueCat Wrapper

**New file:** `MakerMargins/Engine/EntitlementManager.swift`

```swift
import RevenueCat

@Observable
final class EntitlementManager {
    private(set) var isPro: Bool = false
    private(set) var isInTrial: Bool = false
    private(set) var trialDaysRemaining: Int = 0
    private(set) var activeEntitlement: Entitlement?
    private(set) var availablePackages: [Package] = []

    enum Entitlement { case trial, annual, lifetime, none }

    init() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)
        Task { await loadOfferings() }
        Task { await observeCustomerInfo() }
    }

    func purchase(package: Package) async throws { /* ... */ }
    func restorePurchases() async throws { /* ... */ }
    func refreshCustomerInfo() async { /* ... */ }
    func introOfferEligible(for package: Package) async -> Bool { /* ... */ }

    private func loadOfferings() async { /* ... */ }
    private func observeCustomerInfo() async { /* ... */ }
    private func updateState(from customerInfo: CustomerInfo) { /* ... */ }
}
```

**Properties derived from `customerInfo.entitlements["pro"]`:**
- `isPro` — `.isActive == true`
- `isInTrial` — `periodType == .trial`
- `trialDaysRemaining` — computed from `expirationDate` when in trial
- `activeEntitlement` — `.trial | .annual | .lifetime | .none`
- `availablePackages` — loaded from `Purchases.shared.offerings()`

**Trial state is delegated to RevenueCat.** Their backend tracks trial start + expiration accurately across devices. No manual `UserDefaults.firstLaunchDate` tracking.

- `EnvironmentKey` + `EnvironmentValues` extension for injection
- Follows the existing manager pattern (`LaborRateManager`, `AppearanceManager`, `CurrencyFormatter`)

### 2b.7 Defensive Init in MakerMarginsApp

**Modified:** [MakerMargins/MakerMarginsApp.swift](MakerMargins/MakerMarginsApp.swift)

**Critical ordering discipline** — SwiftData first, vendor SDKs wrapped defensively:

```swift
@main
struct MakerMarginsApp: App {
    let modelContainer: ModelContainer
    @State private var analytics = AnalyticsManager()
    @State private var entitlements = EntitlementManager()
    // ... existing managers

    init() {
        // 1. SwiftData first — has its own in-memory fallback
        self.modelContainer = Self.buildContainerWithFallback()

        // 2. Local-only, non-network services (cannot fail catastrophically)
        AppLogger.lifecycle.info("Launching MakerMargins")

        // 3. Vendor SDKs — each wrapped defensively
        do {
            try ErrorReporter.start()
        } catch {
            AppLogger.lifecycle.error("Sentry init failed: \(error.localizedDescription, privacy: .public)")
        }

        MetricsSubscriber.register()

        // PostHog and RevenueCat SDKs are init-safe — queue offline, retry automatically.
        // Called via @State property initialization above.
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(\.analytics, analytics)
                .environment(\.entitlementManager, entitlements)
                // ... other env injections
        }
    }
}
```

**Rules:**
1. SwiftData init first. Existing in-memory fallback stays the first line of defense.
2. Vendor SDK init wrapped in `do/try/catch` or designed to be init-safe. Each must log-and-continue on failure, never crash.
3. No vendor SDK init blocks the main thread on network calls. PostHog and RevenueCat queue offline.
4. Call `AppLogger.lifecycle.info(...)` early so any crashes after this point are easier to diagnose.

**Test scenarios (verified in Phase 4, but designed for here):**
- No network (airplane mode first install) — must succeed
- Corrupt SwiftData store — must fall back to in-memory
- Empty `Secrets.dev.xcconfig` — must launch, vendors just don't connect
- Vendor SDK throws during configure — must log and continue

---

## Sub-Phase 2c — Monetization UI

### 2c.1 PaywallView

**New folder:** `MakerMargins/Views/Paywall/`
**New file:** `MakerMargins/Views/Paywall/PaywallView.swift`

- Presented as `.sheet(isPresented:)` from gated entry points
- Accepts a `PaywallReason` enum:
  ```swift
  enum PaywallReason {
      case productLimit
      case platformLocked(PlatformType)
      case manual
  }
  ```
- Contextual headlines based on reason:
  - `.productLimit` → "You've built 3 products. Unlock unlimited to grow your catalog."
  - `.platformLocked(.shopify)` → "Unlock Shopify pricing to compare channels."
  - `.manual` → generic "Upgrade to Pro"
- Layout:
  - Hero: Pro features list with SF Symbols
  - Two purchase buttons side-by-side: **Annual $19.99/yr** (with dynamic trial badge) and **Lifetime $49.99** (with "Best value" badge)
  - Restore Purchases link
  - Terms of Use + Privacy Policy links (required by Apple Guideline 3.1.2)
- Button actions call `EntitlementManager.purchase(package:)`
- Dismisses automatically on successful purchase (observes `isPro` transition)
- Follows [AppTheme.swift](MakerMargins/Theme/AppTheme.swift) tokens and shared components (`.heroCardStyle()`, `.cardStyle()`)
- Fires analytics signals: `paywallShown` on appear with reason payload, `paywallDismissed` on dismiss, `purchaseAttempted` / `purchaseSucceeded` / `purchaseFailed` around the purchase call

### 2c.2 Dynamic Trial Eligibility (Consumed-Trial Edge Case)

**Critical reviewer edge case:** Apple reviewers often use sandbox accounts that have already consumed intro offers on other apps. RevenueCat's behavior: the `mm_pro_annual` offering is still purchasable, but **without** the 14-day trial. If the paywall unconditionally shows "14 days free," it's visually misleading and can trigger Guideline 3.1.2 rejection.

**Fix in EntitlementManager + PaywallView:**
```swift
// In EntitlementManager
func introOfferEligible(for package: Package) async -> Bool {
    let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(packages: [package])
    return result[package.identifier] == .eligible
}

// In PaywallView
var annualPriceDisplay: String {
    if eligibleForTrial {
        return "14-day free trial, then \(annualPackage.localizedPriceString)/year"
    } else {
        return "\(annualPackage.localizedPriceString)/year"
    }
}
```

Hide the "14-day free trial" badge if ineligible. Purchase flow must still work, just without the trial.

### 2c.3 Gating Layer

**[ProductListView.swift](MakerMargins/Views/Products/ProductListView.swift):**
```swift
@Environment(\.entitlementManager) private var entitlementManager
@State private var showPaywall = false
@State private var paywallReason: PaywallReason = .manual

// In create-product action:
if !entitlementManager.isPro && products.count >= 3 {
    paywallReason = .productLimit
    showPaywall = true
} else {
    // existing create flow
}
```

- Also gate template application when it would push past 3 products
- Duplicate action gated identically
- `.sheet(isPresented: $showPaywall) { PaywallView(reason: paywallReason) }`

**[PricingCalculatorView.swift](MakerMargins/Views/Products/PricingCalculatorView.swift):**
- The tab picker already iterates `PlatformType.allCases`
- Add a lock badge (SF `lock.fill`) to Shopify and Amazon tabs when `!entitlementManager.isPro`
- Tapping a locked tab presents the paywall sheet with `reason: .platformLocked(.shopify)` instead of switching
- General and Etsy tabs behave unchanged for free users

### 2c.4 Settings Pro Section

**[SettingsView.swift](MakerMargins/Views/Settings/SettingsView.swift):** new "MakerMargins Pro" section at top:

- **If Pro:** show active entitlement (`Annual — renews [date]` or `Lifetime — thanks!`) + Manage Subscription link (opens system sheet via `showManageSubscriptions`)
- **If Trial:** show trial days remaining + "Upgrade now" button
- **If Free:** show "Upgrade to Pro" button → presents `PaywallView(reason: .manual)`
- **Always visible:** "Restore Purchases" row calling `entitlementManager.restorePurchases()`
- **Always visible:** Terms of Use + Privacy Policy links

---

## Sub-Phase 2d — Telemetry Wiring

### 2d.1 Settings Privacy Section

**[SettingsView.swift](MakerMargins/Views/Settings/SettingsView.swift):** new "Privacy" section:

- **Share anonymous usage data** — toggle bound to `analytics.isEnabled`, defaults ON
- **What we collect** — disclosure sheet with plain-English bullet list of exactly what is and isn't sent:
  - "We send: anonymous crash reports, anonymous usage events (which screens, which features), trial/purchase events."
  - "We never send: your product names, costs, labor times, supplier info, or any data you've entered."
- **Privacy Policy link** — same URL as the Paywall (Phase 3 hosts it)

### 2d.2 Instrumentation Sites

Add `analytics.signal(.signalName, payload: [...])` calls at:

| View | Signals |
|---|---|
| [MakerMarginsApp.swift](MakerMargins/MakerMarginsApp.swift) | `appLaunched` on launch; `firstLaunch` only on true first launch (check UserDefaults) |
| [ProductListView.swift](MakerMargins/Views/Products/ProductListView.swift) | `productCreated` (always), `productDuplicated`, `firstProductCreated` (once) |
| [PricingCalculatorView.swift](MakerMargins/Views/Products/PricingCalculatorView.swift) | `platformTabViewed` with platform payload on tab switch; `firstPricingCalculated` (once) |
| [PortfolioView.swift](MakerMargins/Views/Products/PortfolioView.swift) | `portfolioViewed` on appear |
| [BatchForecastView.swift](MakerMargins/Views/Products/BatchForecastView.swift) | `batchForecastUsed` when batch size changes from 0 |
| [StopwatchView.swift](MakerMargins/Views/Labor/StopwatchView.swift) | `stopwatchCompleted` on save with bucketed batch size; `firstStopwatchUsed` (once) |
| [TemplatePickerView.swift](MakerMargins/Views/Products/TemplatePickerView.swift) | `templateApplied` with template id |
| `PaywallView.swift` | `paywallShown`, `paywallDismissed`, `purchaseAttempted`, `purchaseSucceeded`, `purchaseFailed`, `restorePurchases` |
| [SettingsView.swift](MakerMargins/Views/Settings/SettingsView.swift) | `settingsOpened`, `currencyChanged`, `appearanceChanged` |

**Privacy enforcement:** before each signal, manually verify no SwiftData field values are passed as payload. Audit happens in Phase 4.

### 2d.3 Privacy Nutrition Label Source of Truth

The label gets filled in App Store Connect in Phase 3. The **expected final state** (used to validate Phase 3 data entry):

| Category | Type | Linked to User | Tracking | Purpose |
|---|---|---|---|---|
| Diagnostics | Crash Data | **No** | **No** | App Functionality |
| Diagnostics | Performance Data | **No** | **No** | App Functionality |
| Usage Data | Product Interaction | **No** | **No** | Analytics |
| Purchases | Purchase History | **No** | **No** | App Functionality |

**No data "Linked to You." No "Tracking." No ATT prompt.**

---

## Sub-Phase 2e — Edge Cases & Conventions

### 2e.1 CostingEngine Purity Guarantee

Add explicit comment banner to [MakerMargins/Engine/CostingEngine.swift](MakerMargins/Engine/CostingEngine.swift):

```swift
// CostingEngine is the designated port target for Android and web.
// It imports only Foundation. It has no dependencies on SwiftData,
// SwiftUI, or any platform APIs. Keep it this way — all cross-platform
// math must remain here.
```

Already true in current code. This just enshrines the convention so future contributors don't leak platform dependencies into calculation logic.

### 2e.2 Localization Scaffolding (Convention, Not Refactor)

For Epic 7 work **only**: wrap user-facing strings in `String(localized: "key", comment: "context")` or use SwiftUI `Text("key")` which auto-localizes.

- **New code (Paywall, Privacy section, gating messages, etc.):** localized strings from day one
- **Modified code (touched lines in Settings, ProductListView, PricingCalculatorView):** adopt localized strings for the modified lines only
- **Untouched code:** leave alone, will be addressed in a future localization epic

**New file:** `MakerMargins/Localizable.xcstrings` with English entries auto-populated by Xcode.

### 2e.3 First-Run / Reviewer Experience

Apple reviewers land on a fresh install and decide in ~60 seconds whether the app meets "minimum functionality" (Guideline 2.1). Engineering work to support this:

- **Trial status indicator** in Settings (and optionally as a dismissible banner on first launch) — so reviewers know they're in trial mode
- **Empty `ProductListView` → "Start from Template" CTA** is a hero element, not a small button (verify existing implementation)
- **First template application lands on Build tab**, not the edit form, so the reviewer sees the cost breakdown immediately
- **No modal interruptions** on first launch (no "Welcome" sheet, no "Please rate us," no "Allow notifications")
- **Paywall only triggers on explicit action** — never during normal browsing

Verification walkthrough happens in Phase 4. Engineering responsibility here is just to make sure the code supports the 60-second path.

---

## Sub-Phase 2f — Tests

Write tests alongside the sub-phases. By the end of Phase 2:

**New files in `MakerMarginsTests/`:**

### `EntitlementTests.swift`
- Mock `CustomerInfo` with `.active` entitlement → `isPro == true`
- Mock `CustomerInfo` with expired entitlement → `isPro == false`
- Mock `CustomerInfo` with trial period type → `isInTrial == true`, `trialDaysRemaining` computed correctly
- Mock lifetime non-consumable entitlement → `isPro == true`, `activeEntitlement == .lifetime`
- Gating logic: free user with 3 products → paywall triggers; Pro user with 3 products → no paywall
- Platform tab gating: `shouldGate(.etsy) == false`, `shouldGate(.shopify) == true` for free
- Restore flow updates `isPro` correctly
- **Consumed-trial case:** paywall display logic hides trial badge when ineligible

**RevenueCat mocking:** use a test double conforming to a thin protocol around `Purchases.shared` so tests inject fake `CustomerInfo` without network calls.

### `AnalyticsTests.swift`
- Signal enum stability (raw values don't change unexpectedly)
- Disabled-state no-ops (when `isEnabled = false`, signals don't fire)
- Payload sanitization (verify no SwiftData field values slip through the payload allowlist)
- Opt-out state persistence in UserDefaults

### `RepositoryTests.swift`
- Write paths through each repository
- `updatedAt` enforcement on every write (create, update, delete, duplicate)
- `remoteID` is `nil` by default and stable across save/load
- Duplicate creates a new entity with a new `remoteID` and fresh timestamps

### `ModelIdentityTests.swift`
- `createdAt`, `updatedAt`, `remoteID` behave correctly across save/load for all 8 models
- `updatedAt` advances on mutation, `createdAt` does not
- `remoteID` is stable across save/load cycles when set

### `AppLaunchTests.swift`
- SwiftData init fallback works when store is corrupted
- Vendor SDK init failures are caught and logged, not propagated
- App can launch with empty `Secrets` values

All tests must pass in CI before Phase 2 gate.

---

## Phase 2 Completion Gate

Phase 4 cannot begin until:

- [ ] ✅ All 8 `@Model` classes have `remoteID`, `createdAt`, `updatedAt`
- [ ] ✅ Schema version bumped in `MakerMarginsApp.swift`
- [ ] ✅ 4 repositories exist and enforce `updatedAt = .now` on writes
- [ ] ✅ All view write paths go through repositories (grep for `modelContext.insert` / `modelContext.delete` outside repository files — should be zero)
- [ ] ✅ `AppLogger.swift` exists with 6 categories
- [ ] ✅ `ErrorReporter.swift` + Sentry SDK integrated, privacy-configured
- [ ] ✅ `MetricsSubscriber.swift` + MetricKit integrated, crash counts forwarded to PostHog
- [ ] ✅ `AnalyticsManager.swift` + PostHog SDK integrated with opt-out toggle
- [ ] ✅ `AnalyticsSignal.swift` enum defined and used everywhere
- [ ] ✅ `EntitlementManager.swift` + RevenueCat SDK integrated, including consumed-trial handling
- [ ] ✅ `PaywallView.swift` exists with all 3 `PaywallReason` variants, dynamic trial eligibility, analytics signals
- [ ] ✅ Product cap gating in `ProductListView` (create + duplicate + template)
- [ ] ✅ Shopify + Amazon tab gating in `PricingCalculatorView`
- [ ] ✅ Settings Pro section + Privacy section
- [ ] ✅ Analytics instrumentation at all specified sites
- [ ] ✅ Defensive init ordering in `MakerMarginsApp.swift`
- [ ] ✅ `CostingEngine.swift` purity comment banner added
- [ ] ✅ `Localizable.xcstrings` exists; new/modified strings use localized keys
- [ ] ✅ [plans/schema-canonical.md](schema-canonical.md) and [plans/analytics-signals.md](analytics-signals.md) created
- [ ] ✅ All 5 new test files exist and pass in CI
- [ ] ✅ Existing 203-test suite still passes
- [ ] ✅ Full build succeeds with PostHog + Sentry + RevenueCat SPM deps
- [ ] ✅ Debug build in simulator: `appLaunched` signal arrives in PostHog dashboard within seconds
- [ ] ✅ Debug build: complete activation flow (template apply → product → pricing → portfolio) produces expected funnel signals
- [ ] ✅ Console.app shows OSLog output under `com.makermargins.app` subsystem; private values redacted in release build

---

## Files Touched in Phase 2

**New (Engine):**
- `MakerMargins/Engine/AppLogger.swift`
- `MakerMargins/Engine/AnalyticsManager.swift`
- `MakerMargins/Engine/AnalyticsSignal.swift`
- `MakerMargins/Engine/ErrorReporter.swift`
- `MakerMargins/Engine/MetricsSubscriber.swift`
- `MakerMargins/Engine/EntitlementManager.swift`

**New (Repositories):**
- `MakerMargins/Repositories/ProductRepository.swift`
- `MakerMargins/Repositories/WorkStepRepository.swift`
- `MakerMargins/Repositories/MaterialRepository.swift`
- `MakerMargins/Repositories/CategoryRepository.swift`

**New (Views):**
- `MakerMargins/Views/Paywall/PaywallView.swift`

**New (Tests):**
- `MakerMarginsTests/EntitlementTests.swift`
- `MakerMarginsTests/AnalyticsTests.swift`
- `MakerMarginsTests/RepositoryTests.swift`
- `MakerMarginsTests/ModelIdentityTests.swift`
- `MakerMarginsTests/AppLaunchTests.swift`

**New (Resources):**
- `MakerMargins/Localizable.xcstrings`

**New (Plans):**
- [plans/schema-canonical.md](schema-canonical.md)
- [plans/analytics-signals.md](analytics-signals.md)

**Modified:**
- All 8 `@Model` files — add `remoteID`, `createdAt`, `updatedAt`
- [MakerMargins/MakerMarginsApp.swift](MakerMargins/MakerMarginsApp.swift) — defensive init ordering, inject new managers
- [MakerMargins/Engine/CostingEngine.swift](MakerMargins/Engine/CostingEngine.swift) — purity comment banner
- [MakerMargins/Views/Settings/SettingsView.swift](MakerMargins/Views/Settings/SettingsView.swift) — Pro section, Privacy section, legal links, instrumentation
- [MakerMargins/Views/Products/ProductListView.swift](MakerMargins/Views/Products/ProductListView.swift) — gating, repository writes, instrumentation
- [MakerMargins/Views/Products/PricingCalculatorView.swift](MakerMargins/Views/Products/PricingCalculatorView.swift) — tab gating, instrumentation
- [MakerMargins/Views/Products/PortfolioView.swift](MakerMargins/Views/Products/PortfolioView.swift) — instrumentation
- [MakerMargins/Views/Products/BatchForecastView.swift](MakerMargins/Views/Products/BatchForecastView.swift) — instrumentation
- [MakerMargins/Views/Products/TemplatePickerView.swift](MakerMargins/Views/Products/TemplatePickerView.swift) — instrumentation
- [MakerMargins/Views/Labor/StopwatchView.swift](MakerMargins/Views/Labor/StopwatchView.swift) — instrumentation
- All other views with write paths — switch to repository calls
- [MakerMargins/Engine/TemplateApplier.swift](MakerMargins/Engine/TemplateApplier.swift) — write through repositories
- [project.yml](project.yml) — PostHog + Sentry + RevenueCat SPM deps
