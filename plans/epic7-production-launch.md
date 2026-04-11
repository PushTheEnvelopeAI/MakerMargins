# Epic 7 — Production Readiness & App Store Launch

> Master roadmap for shipping MakerMargins 1.0 to the iOS App Store. This file is the **navigator** — read it to understand the shape and order of the work. Read the phase files to execute.

**Status:** In Progress

---

## Epic Goal

Ship MakerMargins 1.0 to the iOS App Store with:
- A sustainable monetization model (freemium + RevenueCat-wrapped StoreKit 2)
- Real-time operational visibility (PostHog analytics + Sentry errors)
- Cross-platform-ready architecture that doesn't block future Android + web
- A clean Apple Review on first submission

---

## Resolved Decisions

These are locked and drive the rest of the work. Do not revisit without cause.

| Decision | Choice | Rationale |
|---|---|---|
| Publishing entity | LLC as Organization | Tax cleanliness, liability separation, Apple is merchant-of-record for EU VAT |
| Device scope | iPhone only (iPad deferred to v1.1+) | ~1-2 weeks of iPad layout work not justified at launch |
| Storefronts | US + Europe | Small paperwork cost (DSA + GDPR), big market |
| Monetization | Freemium, $19.99/yr + $49.99 lifetime, 14-day trial, no monthly | Bursty usage pattern mismatches monthly subs |
| App name | MakerMargins | Final |
| Marketing landing page | Yes — Carrd + custom domain | Required for LLC Dev Program enrollment anyway |
| iOS deployment target | iOS 26 (unless revisited in Phase 1 decision) | Current CLAUDE.md default |
| Analytics vendor | PostHog | Cross-platform, feature flags, privacy-first |
| Crash reporting vendor | Sentry | Cross-platform, mature SDKs |
| Subscription vendor | RevenueCat (wrapping StoreKit 2) | Cross-platform entitlements for future Android + web |
| Future backend vendor | Supabase (not built in 1.0) | Postgres, cross-platform SDKs, self-hostable |

Full monetization analysis archived at `C:\Users\aj100\.claude\plans\fizzy-exploring-ember.md`. Cross-platform architectural commitments documented in [CLAUDE.md](../CLAUDE.md).

---

## Free vs Pro Tier Summary

**Free:** 3 products, unlimited WorkSteps and Materials, General + Etsy pricing tabs, Batch Forecasting, Portfolio Metrics, all templates, USD + EUR, all settings.

**Pro ($19.99/yr or $49.99 lifetime, 14-day trial):** unlimited products, Shopify + Amazon pricing tabs, all future Tier-1 roadmap features.

**Two paywalls:** 3-product cap (scale wall) + Shopify/Amazon tabs (breadth wall).

Full detail in [epic7-phase2-engineering.md](epic7-phase2-engineering.md).

---

## Phase Structure

| Phase | Scope | Sub-Plan | Runs When |
|---|---|---|---|
| **1. Foundation** | Accounts, infrastructure, CI release pipeline, IAP products, secrets, decisions | [epic7-phase1-foundation.md](epic7-phase1-foundation.md) | Start day 1. Week 1. |
| **2. Engineering** | All code: models, repositories, vendor SDKs, paywall, gating, instrumentation, tests | [epic7-phase2-engineering.md](epic7-phase2-engineering.md) | After Phase 1 infra ready. Weeks 2-3. |
| **3. Assets & Content** | Landing page build-out, Privacy Policy, Terms, screenshots, app icon, store metadata, DSA trader info, DPAs | [epic7-phase3-assets.md](epic7-phase3-assets.md) | **Parallel with Phase 2.** Weeks 2-3. |
| **4. Ship** | Pre-submission QA, TestFlight beta, crash-free baseline, submission, review, phased release | [epic7-phase4-ship.md](epic7-phase4-ship.md) | After Phases 2 + 3 complete. Weeks 4-5. |

---

## Critical Path

The unavoidable dependency chain that determines earliest possible submission:

```
Day 1   ── Register domain + placeholder page (1 hour)
        ── Apply for D-U-N-S number (1-5 business days wait)
        ── Create vendor accounts (PostHog, Sentry, RevenueCat)
        ── Start beta tester recruitment
        ── iOS deployment target decision
        ── Start template image provenance audit

Day 3-7 ── D-U-N-S issues
        ── Apple Developer Program enrollment as Organization
        ── App Store Connect access granted
        ── Agreements / Tax / Banking filled under LLC EIN
        ── IAP products created (mm_pro_annual, mm_pro_lifetime)
        ── RevenueCat dashboard mirrors IAP products
        ── DSA Trader Status filled in ASC

Day 5-10── Mac CI release workflow built + tested with pre-release tag
        ── Secret management infrastructure (.xcconfig + Secrets.swift)
        ── Info.plist photo library permission added

Day 7+  ── PHASE 2 (engineering) begins
        ── PHASE 3 (assets) runs in parallel

Day 21+ ── Phases 2 + 3 feature-complete
        ── PHASE 4 (ship) begins with QA sweep

Day 24+ ── TestFlight internal build via CI release
        ── External TestFlight beta opens (5+ day window)

Day 33+ ── Crash-free 48-hour baseline confirmed
        ── Submit to App Review

Day 35+ ── Apple Review (24-48h typical, 3-5 days for new subscription apps)

Day 40+ ── Approval → Phased Release 7-day rollout begins
```

**Earliest realistic submission:** ~5-6 weeks from kickoff. **Earliest public availability:** ~6-7 weeks from kickoff. Pad for slippage.

### Biggest Timeline Risks
- **D-U-N-S processing delay** (could add 1-2 weeks if the LLC record needs correction at D&B)
- **Apple Developer Program verification call** (sometimes Apple calls the listed phone for authorization — unreachable phone = stalled enrollment)
- **First-time Mac CI release workflow debugging** (budget 2x your estimate; certs + keychain + signing is finicky)
- **Apple Review rejection requiring code changes** (budget at least 1 rejection cycle for subscription apps)

---

## Gates Between Phases

Each phase must satisfy its completion gate before the next phase can start. Gates are verification checkpoints, not paperwork.

### Phase 1 → Phase 2 Gate
Phase 2 cannot begin until:
- ✅ Mac CI release workflow has successfully uploaded a pre-release build to TestFlight (proves the pipeline works before Phase 4 depends on it)
- ✅ `.xcconfig` secret management wired in; `Secrets.swift` can read values; debug build launches without crashing on empty secrets
- ✅ IAP products exist in both App Store Connect AND RevenueCat dashboard (needed for EntitlementManager testing against sandbox)
- ✅ Info.plist photo library permission present (otherwise engineering debug builds crash)
- ✅ iOS deployment target decision finalized and documented in CLAUDE.md
- ✅ LLC fully enrolled in Apple Developer Program with Agreements/Tax/Banking complete

### Phase 2 / 3 → Phase 4 Gate
Phase 4 cannot begin until both Phase 2 and Phase 3 are feature-complete:
- ✅ All vendor SDKs integrated and logging to their dashboards in dev builds
- ✅ PaywallView, EntitlementManager, gating layer all working end-to-end
- ✅ All analytics instrumentation sites firing correctly
- ✅ All tests passing in CI (existing 203 + new Epic 7 test files)
- ✅ Marketing landing page live with Privacy Policy + Terms hosted
- ✅ Screenshots captured, annotated, ready to upload
- ✅ App Store Connect metadata drafted (name, subtitle, description, keywords)
- ✅ Privacy Nutrition Labels drafted
- ✅ App Review notes drafted

### Phase 4 → Epic Complete Gate
Epic 7 is complete when:
1. ✅ External TestFlight beta has run ≥5 days with ≥3 real testers
2. ✅ Sentry reports ≥48 consecutive hours crash-free before submission
3. ✅ All sandbox purchase flows verified: trial start, trial expiry, annual purchase, lifetime purchase, refund, restore, consumed-trial paywall display
4. ✅ Privacy audit complete: no PII in analytics, no user content in error reports, Privacy Nutrition Label matches reality
5. ✅ App Store Connect ready-for-review checklist is 100% green
6. ✅ Build has been **approved** by Apple Review
7. ✅ MakerMargins 1.0 is available on the App Store in US + European storefronts
8. ✅ CLAUDE.md updated with any architectural decisions made during implementation

---

## Out of Scope (Deferred to Epic 8)

Explicitly not Epic 7's problem, captured in [epic8-post-launch-operations.md](epic8-post-launch-operations.md):

- Monitoring dashboards + alerting rules
- Incident response playbook
- Review response plan + templates
- Support workflow + SLAs
- Update cadence + release management
- Launch marketing (Product Hunt, Reddit, press, email waitlist payoff)
- Ongoing ASO + keyword iteration
- Financial/LLC operational hygiene (bookkeeping, tax, payouts, backups)
- Feature flag experiments
- Post-launch community building

---

## File Structure (Epic 7)

```
plans/
├── epic7-production-launch.md       ← you are here (roadmap + index)
├── epic7-phase1-foundation.md       ← accounts, infra, CI, secrets, IAPs
├── epic7-phase2-engineering.md      ← all code work
├── epic7-phase3-assets.md           ← content, legal, visuals, metadata (parallel with phase 2)
├── epic7-phase4-ship.md             ← QA, beta, submission, review
├── epic8-post-launch-operations.md  ← everything after launch (deferred)
├── asset-provenance.md              ← created in phase 3
├── schema-canonical.md              ← created in phase 2
├── analytics-signals.md             ← created in phase 2
└── release-runbook.md               ← created in phase 1
```

---

## Cross-References

- **Monetization strategy analysis:** archived at `C:\Users\aj100\.claude\plans\fizzy-exploring-ember.md`
- **Architectural conventions + cross-platform future:** [CLAUDE.md](../CLAUDE.md)
- **Prior epic acceptance criteria:** [plans/epic-acceptance-criteria.md](epic-acceptance-criteria.md)
- **Post-launch epic:** [plans/epic8-post-launch-operations.md](epic8-post-launch-operations.md)
