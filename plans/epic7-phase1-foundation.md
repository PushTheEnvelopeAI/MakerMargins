# Epic 7 — Phase 1: Foundation

> **Parent:** [epic7-production-launch.md](epic7-production-launch.md)
> **Goal:** Stand up every external account, paperwork item, and piece of infrastructure that Phase 2 (engineering) will depend on. **Nothing in Phase 2 can start until Phase 1's gate is passed.**

**Status:** In Progress.
**Estimated duration:** ~1 week (bounded by D-U-N-S processing wait).

---

## Phase Goal

By the end of Phase 1, you should be able to say yes to all of these:
- LLC is fully enrolled in the Apple Developer Program as an Organization
- App Store Connect record exists with Agreements/Tax/Banking complete
- IAP products (`mm_pro_annual`, `mm_pro_lifetime`) exist in App Store Connect **and** RevenueCat dashboard
- Mac CI release workflow has successfully uploaded at least one pre-release build to TestFlight
- `.xcconfig` secret management is wired and working
- The engineering debug build launches without crashing on photo picker tap
- iOS deployment target decision is locked in
- Beta tester recruitment has started
- Vendor accounts (PostHog, Sentry, RevenueCat) exist with production project keys

---

## Day 1 — Parallel Kickoff

These all start on the same day. None block each other.

### 1.1 Register Domain + Placeholder Landing Page (1 hour) — DONE
- [x] Registered `makermargins.app` via Cloudflare Registrar.
- [x] Configured DNS to Cloudflare Pages (Workers & Pages static asset upload).
- [x] Deployed "Coming Soon" placeholder page at `https://makermargins.app`. Source at `landing/index.html`.
- [x] HTTPS verified on PC and iPhone.
- [x] Cloudflare Email Routing enabled: catch-all → `thebagelboardco@gmail.com`. `admin@makermargins.app` works via catch-all.

### 1.2 Apply for D-U-N-S Number (~15 min, 1-5 business days wait) — DONE
- [x] Business Apple ID created using `admin@makermargins.app` (took ~48 hours due to Apple fraud detection on new domain; resolved by waiting for throttle reset).
- [x] D-U-N-S number applied for and issued.
- [x] D-U-N-S record verified against LLC state filing.

### 1.3 Create Vendor Accounts (1 hour) — DONE
- [x] **PostHog:** account created, project "MakerMargins" created, API key + host URL saved.
- [x] **Sentry:** account created, org "The Bagel Board Company LLC", project "makermargins" (iOS), DSN saved, org auth token (`makermargins-ci-release`, `org:ci` scope) created and saved.
- [x] **RevenueCat:** account created, project "makermargins", public SDK key saved (auto-generated "Test Store" key). Email confirmed. Full platform config (shared secret, bundle ID, products, entitlements) deferred to Task 1.11 after Developer Program enrollment completes.
- [x] All five key values archived in password manager (PostHog API key, PostHog host, Sentry DSN, Sentry org auth token, RevenueCat public SDK key).

### 1.4 Beta Testing Approach — DECIDED
- [x] **Decision:** Solo beta testing. The developer is a working maker (woodworker) and will use the app with real business data — real products, real labor times, real material costs, real pricing decisions. This is genuine end-to-end usage, not simulated.
- [x] **Post-launch recruitment:** After App Store release, recruit initial users from maker groups the developer is already part of. First-wave user feedback replaces the traditional external beta.
- [x] **Tradeoff accepted:** Solo beta misses first-time-user UX friction (builder blind spots). Mitigated by post-launch review monitoring and rapid iteration (Epic 8).
- **Note:** Phase 4 verification gates updated to reflect solo beta approach (no external tester minimum required).

### 1.5 iOS Deployment Target Decision (5 min) — DONE
- [x] **Decision: keep iOS 26.** Entire UI is built with Liquid Glass; dropping target would require full backwards-compatibility audit (~1-2 weeks). Wider device reach deferred to a post-launch update if adoption data justifies it.
- [x] Documented in CLAUDE.md.

### 1.6 Template Image Provenance Audit (30 min self-review) — DONE
- [x] All 42 template images generated with **Google Gemini**. Google's ToS grants commercial distribution rights. No royalty, no attribution required.
- [x] Provenance documented in [plans/asset-provenance.md](asset-provenance.md) with full inventory (5 products, 18 work steps, 19 materials).
- [x] No images with unclear provenance. No replacements needed.

---

## Week 1 — Account Enrollment Chain

These are sequential — each depends on the previous completing.

### 1.7 Apple Developer Program Enrollment as Organization — IN PROGRESS
**Prerequisite:** D-U-N-S number issued (from 1.2).

- [x] Enrolled LLC at developer.apple.com ($99/yr) as **Organization**. Submitted and paid.
- [x] D-U-N-S number and LLC legal name provided.
- [ ] **Waiting for Apple verification** — may include a phone call. Keep phone reachable and answer unknown numbers.
- [ ] Enrollment typically completes in 1-3 business days after phone verification.
- [ ] Once active: verify access to developer.apple.com + appstoreconnect.apple.com, note Team ID from Membership page.

### 1.8 App Store Connect Setup (after enrollment)
- [ ] Register bundle identifier in the Apple Developer portal under the LLC account (e.g. `com.yourllc.makermargins`).
- [ ] Create App ID with **In-App Purchase** capability enabled.
- [ ] Distribution certificate and App Store provisioning profile (Xcode + Mac CI runner generate these).
- [ ] **App Store Connect → Agreements, Tax, and Banking** filled out under LLC EIN and business bank account. Separate step from enrollment; must complete before any paid app can be sold.
- [ ] Create App Store Connect app record:
  - Name: MakerMargins
  - Primary language: English (US)
  - Bundle ID: matches what was registered
  - SKU: internal identifier (e.g. `MAKERMARGINS_IOS_001`)
- [ ] **Optional:** file a DBA with the state if you want the store to display a trade name (e.g. "MakerMargins Software") instead of the LLC's legal name. Configure in Agreements → Paid Apps → Legal Entity Name.

### 1.9 DSA Trader Status (EU Requirement — can be done early)
EU sales require this or Apple removes the app from EU storefronts.

- [ ] **App Store Connect → Agreements → Trader Status** — fill in:
  - LLC legal name
  - Registered business address (note: this is published publicly on EU App Store listings — consider using a registered agent address if privacy is a concern)
  - Phone number
  - Email address
  - Trade register number (state registration number or EIN)
- [ ] The same info must later appear on the marketing landing page footer (Phase 3 task).

---

## Week 1 — In-App Purchase Products

**Prerequisite:** App Store Connect access + Agreements/Tax/Banking complete.

### 1.10 App Store Connect IAP Products
- [ ] Create subscription group **"MakerMargins Pro"**.
- [ ] Create `mm_pro_annual`:
  - Type: auto-renewing subscription
  - Duration: 1 year
  - Price: $19.99 USD base (Apple auto-fills EU prices via price tier system)
  - **No intro offer / free trial** — the free tier (3 products, General + Etsy) IS the trial
  - Localized display name + description (English)
  - Review screenshot (can use a placeholder until Phase 3 generates the real paywall screenshot)
- [ ] Create `mm_pro_lifetime`:
  - Type: non-consumable IAP
  - Price: $49.99 USD base
  - Localized display name + description (English)
  - Review screenshot
- [ ] Confirm **pricing tiers in US and European storefronts**. Let Apple auto-fill EU tiers from the $19.99 / $49.99 base; override per-country only if rounding feels wrong.
- [ ] Subscription tax category selected (usually "Other Services" or similar for software).
- [ ] Products will be submitted for review alongside the app binary in Phase 4.

### 1.11 RevenueCat Dashboard Setup
- [ ] Configure MakerMargins project in RevenueCat with the iOS bundle identifier.
- [ ] Create two products matching App Store Connect identifiers:
  - `mm_pro_annual`
  - `mm_pro_lifetime`
- [ ] Create one **Entitlement** called `pro` that maps to both products.
- [ ] Create one **Offering** called `default` with both packages.
- [ ] Archive the RevenueCat public SDK key — needed for the `.xcconfig` in task 1.13.

---

## Week 1 — Code Infrastructure (Parallel with Enrollment)

These don't depend on Apple enrollment and can be built in parallel while D-U-N-S and Developer Program are processing.

### 1.12 Info.plist Usage Descriptions (5 min — BLOCKING) — DONE
- [x] Added `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` and `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO` to `project.yml` under MakerMargins target build settings. Uses XcodeGen's `INFOPLIST_KEY_*` convention (compatible with `GENERATE_INFOPLIST_FILE: YES`).
- [x] Verified `PhotosPicker` uses `matching: .images` only — no camera access. `NSCameraUsageDescription` not needed.
- [x] Grepped for Location, Microphone, Contacts, Calendar, HealthKit, HomeKit — none found. No other usage descriptions needed.
- [ ] **Verify on CI:** rebuild on macOS runner to confirm photo picker doesn't crash. Will be verified when Phase 2 code lands and CI runs.

### 1.13 Secret Management (1-2 hours — BLOCKING) — DONE

**Approach (revised):** `.xcconfig` approach was abandoned because it breaks the existing CI — XcodeGen validates that referenced `configFiles` exist, and `ci.yml` doesn't create them. Since all development happens on Windows (no local iOS builds), the simpler approach is:

- `Secrets.swift` committed with **empty string constants** as defaults
- The CI release workflow (`release.yml`, Task 1.14) **overwrites `Secrets.swift`** with real values from GitHub Secrets before archiving
- CI test builds (`ci.yml`) use empty defaults — tests don't depend on real vendor keys
- No `.xcconfig` files, no Info.plist injection, no gitignore entries needed
- Existing CI is not broken

**Created:**
- [x] `MakerMargins/Engine/Secrets.swift` — committed with empty defaults, documented for CI overwrite pattern

**How production keys get injected:**
```yaml
# In .github/workflows/release.yml (Task 1.14):
- name: Write production secrets
  run: |
    cat > MakerMargins/Engine/Secrets.swift <<'EOF'
    import Foundation
    enum Secrets {
        static let posthogAPIKey = "${{ secrets.POSTHOG_API_KEY_PROD }}"
        static let posthogHost = "https://us.i.posthog.com"
        static let sentryDSN = "${{ secrets.SENTRY_DSN_PROD }}"
        static let revenueCatAPIKey = "${{ secrets.REVENUECAT_API_KEY_PROD }}"
    }
    EOF
```

### 1.14 Mac CI Release Build & Upload Workflow (4-8 hours — BLOCKING, longest lead) — PARTIALLY DONE

**Workflow file written:** [.github/workflows/release.yml](.github/workflows/release.yml). Triggered by pushing a version tag (`v*.*.*`) or manually via `workflow_dispatch`.

**How secrets are injected:** the workflow overwrites `MakerMargins/Engine/Secrets.swift` with real values from GitHub Secrets before archiving. The committed `Secrets.swift` has empty defaults (safe for test builds).

**Remaining:** configure GitHub Secrets and test the workflow. Blocked on Task 1.7 (Apple Developer Program enrollment) because the distribution certificate, provisioning profile, and App Store Connect API key can only be generated from an active Developer Program account.

#### Required GitHub Secrets

Store in the repo's Settings → Secrets and Variables → Actions:

| Secret Name | Source | How to Obtain |
|---|---|---|
| `DISTRIBUTION_CERTIFICATE_P12_BASE64` | Base64 of `.p12` export of iOS Distribution certificate | Xcode Keychain Access → export → `base64 -i cert.p12 \| pbcopy` |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | Password set during `.p12` export | User-chosen |
| `PROVISIONING_PROFILE_BASE64` | Base64 of `.mobileprovision` file | Developer portal download → base64 |
| `APPSTORE_API_KEY_ID` | App Store Connect API key ID | ASC → Users and Access → Keys → create key |
| `APPSTORE_API_ISSUER_ID` | API issuer ID | Same page, displayed above keys list |
| `APPSTORE_API_KEY_P8_BASE64` | Base64 of the `.p8` file | Downloaded once during key creation — **cannot re-download**, must store safely |
| `KEYCHAIN_PASSWORD` | Temporary keychain password for CI runner | User-chosen, any string |
| `TEAM_ID` | Apple Developer Team ID | Developer portal → Membership |
| `POSTHOG_API_KEY_PROD` | Production PostHog key | PostHog dashboard |
| `SENTRY_DSN_PROD` | Production Sentry DSN | Sentry dashboard |
| `SENTRY_AUTH_TOKEN` | Sentry org auth token for dSYM upload | Sentry → Settings → Auth Tokens |
| `SENTRY_ORG` | Sentry organization slug | Sentry → Settings → General |
| `SENTRY_PROJECT` | Sentry project slug | Sentry → Settings → Projects |
| `REVENUECAT_API_KEY_PROD` | Production RevenueCat public SDK key | RevenueCat dashboard |

#### Workflow File

Create [.github/workflows/release.yml](.github/workflows/release.yml):

```yaml
name: Release

on:
  push:
    tags: [ 'v*.*.*' ]
  workflow_dispatch:

jobs:
  release:
    runs-on: macos-14
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Decode and Install Certificates
        env:
          P12_BASE64: ${{ secrets.DISTRIBUTION_CERTIFICATE_P12_BASE64 }}
          P12_PASSWORD: ${{ secrets.DISTRIBUTION_CERTIFICATE_PASSWORD }}
          KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
        run: |
          security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security set-keychain-settings -lut 21600 build.keychain

          echo "$P12_BASE64" | base64 --decode > cert.p12
          security import cert.p12 -k build.keychain -P "$P12_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" build.keychain
          rm cert.p12

      - name: Install Provisioning Profile
        env:
          PROFILE_BASE64: ${{ secrets.PROVISIONING_PROFILE_BASE64 }}
        run: |
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo "$PROFILE_BASE64" | base64 --decode > ~/Library/MobileDevice/Provisioning\ Profiles/profile.mobileprovision

      - name: Write Production Secrets xcconfig
        env:
          POSTHOG_API_KEY: ${{ secrets.POSTHOG_API_KEY_PROD }}
          SENTRY_DSN: ${{ secrets.SENTRY_DSN_PROD }}
          REVENUECAT_API_KEY: ${{ secrets.REVENUECAT_API_KEY_PROD }}
        run: |
          mkdir -p MakerMargins/Config
          cat > MakerMargins/Config/Secrets.prod.xcconfig <<EOF
          POSTHOG_API_KEY = $POSTHOG_API_KEY
          POSTHOG_HOST = https://us.i.posthog.com
          SENTRY_DSN = $SENTRY_DSN
          REVENUECAT_API_KEY = $REVENUECAT_API_KEY
          EOF

      - name: Generate Xcode Project
        run: xcodegen generate

      - name: Archive
        env:
          TEAM_ID: ${{ secrets.TEAM_ID }}
        run: |
          xcodebuild archive \
            -project MakerMargins.xcodeproj \
            -scheme MakerMargins \
            -configuration Release \
            -archivePath $RUNNER_TEMP/MakerMargins.xcarchive \
            -destination "generic/platform=iOS" \
            CODE_SIGN_STYLE=Manual \
            DEVELOPMENT_TEAM="$TEAM_ID" \
            PROVISIONING_PROFILE_SPECIFIER="MakerMargins App Store"

      - name: Export Archive
        run: |
          cat > ExportOptions.plist <<EOF
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
              <key>method</key>
              <string>app-store</string>
              <key>uploadSymbols</key>
              <true/>
          </dict>
          </plist>
          EOF

          xcodebuild -exportArchive \
            -archivePath $RUNNER_TEMP/MakerMargins.xcarchive \
            -exportOptionsPlist ExportOptions.plist \
            -exportPath $RUNNER_TEMP/export

      - name: Decode App Store Connect API Key
        env:
          API_KEY_BASE64: ${{ secrets.APPSTORE_API_KEY_P8_BASE64 }}
        run: |
          mkdir -p ~/.appstoreconnect/private_keys
          echo "$API_KEY_BASE64" | base64 --decode > ~/.appstoreconnect/private_keys/AuthKey_${{ secrets.APPSTORE_API_KEY_ID }}.p8

      - name: Upload to App Store Connect
        env:
          API_KEY_ID: ${{ secrets.APPSTORE_API_KEY_ID }}
          API_ISSUER_ID: ${{ secrets.APPSTORE_API_ISSUER_ID }}
        run: |
          xcrun altool --upload-app \
            -f $RUNNER_TEMP/export/MakerMargins.ipa \
            -t ios \
            --apiKey "$API_KEY_ID" \
            --apiIssuer "$API_ISSUER_ID"

      - name: Upload dSYMs to Sentry
        env:
          SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
        run: |
          curl -sL https://sentry.io/get-cli/ | bash
          sentry-cli debug-files upload \
            --org your-sentry-org \
            --project makermargins \
            $RUNNER_TEMP/MakerMargins.xcarchive/dSYMs

      - name: Clean Up Keychain
        if: always()
        run: security delete-keychain build.keychain
```

#### Version / Build Number Strategy
- Marketing version from git tag (`v1.0.0` → `1.0.0`)
- Build number from `github.run_number` or auto-incremented from App Store Connect's latest build
- Wire via `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` overrides in the archive step

#### Verification — CRITICAL
**Test the workflow before relying on it.** This is a long-lead, high-risk item.
- [ ] Tag a pre-release (`v0.9.0`) and run `workflow_dispatch` manually.
- [ ] First run must successfully upload to TestFlight as an internal build.
- [ ] Verify dSYM upload lands in Sentry so crash symbolication works.
- [ ] Budget 2x your estimate — keychain + certs + signing is finicky and first-time setup often requires 2-4 iterations.

#### Documentation
- [ ] Create [plans/release-runbook.md](release-runbook.md) with step-by-step instructions for tagging a release, including pre-release checklist and failure recovery.

---

## Phase 1 Completion Gate

Phase 2 cannot begin until all of the following are true:

- [ ] ✅ D-U-N-S issued, LLC enrolled in Apple Developer Program as Organization, phone verification passed
- [ ] ✅ App Store Connect app record exists, Agreements/Tax/Banking complete under LLC EIN
- [ ] ✅ `mm_pro_annual` and `mm_pro_lifetime` exist in App Store Connect **and** RevenueCat dashboard
- [ ] ✅ DSA Trader Status filled in App Store Connect
- [ ] ✅ Mac CI release workflow has successfully uploaded at least one pre-release build to TestFlight (proves the pipeline before Phase 4 depends on it)
- [ ] ✅ `.xcconfig` secret management wired; `Secrets.swift` reads values; debug build launches with empty secrets without crashing
- [ ] ✅ `NSPhotoLibraryUsageDescription` in `project.yml` — debug build can open photo picker without crashing
- [ ] ✅ iOS deployment target decision locked in and documented in [CLAUDE.md](../CLAUDE.md)
- [ ] ✅ Template image provenance audit complete; [plans/asset-provenance.md](asset-provenance.md) archived
- [ ] ✅ Vendor accounts (PostHog, Sentry, RevenueCat) exist with production project keys
- [ ] ✅ Beta testing approach decided (solo beta with real business data; post-launch community recruitment)

---

## Files Touched in Phase 1

**New:**
- [plans/release-runbook.md](release-runbook.md)
- [plans/asset-provenance.md](asset-provenance.md)
- [.github/workflows/release.yml](.github/workflows/release.yml)
- `MakerMargins/Config/Secrets.dev.xcconfig` (gitignored)
- `MakerMargins/Config/Secrets.prod.xcconfig` (gitignored)
- `MakerMargins/Config/Secrets.example.xcconfig` (committed)
- `MakerMargins/Engine/Secrets.swift`

**Modified:**
- [project.yml](project.yml) — `infoPlist` section, `.xcconfig` wiring, version/build settings
- [.gitignore](.gitignore) — add `Secrets.dev.xcconfig` and `Secrets.prod.xcconfig`
- [CLAUDE.md](../CLAUDE.md) — document iOS deployment target decision

**External (not code):**
- GitHub Secrets (12 secrets configured via UI)
- D-U-N-S record
- Apple Developer Program account
- App Store Connect records (app + IAP products + Trader Status + Agreements)
- RevenueCat dashboard (project + products + entitlement + offering)
- PostHog project
- Sentry project
- Domain registration
- Landing page placeholder
