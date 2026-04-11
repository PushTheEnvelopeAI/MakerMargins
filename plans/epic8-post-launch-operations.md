# Epic 8 — Post-Launch Operations, Marketing & Growth

> Umbrella for everything that happens **after** MakerMargins 1.0 is live on the App Store. Blocked on [epic7-production-launch.md](epic7-production-launch.md) completion. Captured now so these concerns don't get lost during the ship push.

**Status:** Planned (blocked on Epic 7 completion)

---

## Epic Goal

Keep MakerMargins healthy, growing, and sustainable after launch. Cover monitoring, incident response, customer support, review management, marketing, ongoing ASO, financial operations, and long-term growth levers.

---

## 1. Monitoring & Observability

### Dashboards
- [ ] **PostHog dashboard** for core product metrics:
  - Activation funnel (install → templateApplied → firstProductCreated → firstPricingCalculated → portfolioViewed)
  - Monetization funnel (paywallShown → purchaseAttempted → purchaseSucceeded)
  - Feature usage heatmap (which tabs, which templates, which calculations get used)
  - Retention cohorts (D1, D7, D30 by install week)
- [ ] **Sentry dashboard** for stability:
  - Crash-free session rate (target: >99.5%)
  - Top errors by frequency and affected users
  - Performance: cold launch time, hangs, slow frames
- [ ] **RevenueCat dashboard** for monetization:
  - Free-to-paid conversion rate
  - MRR, churn, refund rate
  - Annual vs lifetime mix

### Alerting
- [ ] **Sentry alerts** (email + optionally Slack/Discord):
  - Crash rate spike (>5% of sessions crashing in any 1-hour window)
  - New error types affecting >10 users in 24h
  - Performance regression (cold launch >2x baseline)
- [ ] **PostHog alerts:**
  - Activation funnel drop >20% week-over-week
  - Purchase rate drops to zero (possible StoreKit regression)
- [ ] **RevenueCat alerts:** unusual refund spike, purchase volume anomaly

### Cadence
- [ ] **Daily (first 2 weeks):** quick 5-min dashboard check + Sentry triage
- [ ] **Weekly (ongoing):** metrics review, top issues prioritized, response plan updated
- [ ] **Monthly:** cohort analysis, retention trends, revenue review

---

## 2. Incident Response

### Crash Wave Playbook
- [ ] Sentry alert fires → triage within 30 minutes (on-call is you)
- [ ] Severity classification:
  - **P0 — Launch crash or data loss** → immediate hotfix, request expedited review from Apple
  - **P1 — Major feature broken** → hotfix within 48h, normal review
  - **P2 — Edge case or cosmetic** → batch into next scheduled update
- [ ] **Pause phased release** criterion: any P0, or P1 affecting >5% of installed base
- [ ] **Reproduce locally** using Sentry stack trace + breadcrumbs
- [ ] **Fix, test, release new build** with incremented build number, submit for expedited review if P0

### Hotfix Release Process
- [ ] Tag new release (e.g. `v1.0.1`)
- [ ] CI release workflow builds and uploads (see [epic7-phase1-foundation.md](epic7-phase1-foundation.md))
- [ ] App Store Connect submission with **"Expedited Review"** request for P0 only
- [ ] Release notes explaining what was fixed
- [ ] Phased release enabled for the hotfix too (not just initial release)

### Critical Principle: No Real Rollbacks
- [ ] **There is no "roll back to previous version" on the App Store.** Once a new version is approved, the old one stops being downloadable for new installs. The only remediation is a new forward fix. Plan accordingly.

---

## 3. Review Response Plan

### Why This Matters
The first 50–100 reviews disproportionately shape your star rating for the life of the app. A single 1-star review on day 3 with 10 total reviews = 4.1 avg. The same review at 500 reviews = 4.98 avg. Early reviews are very expensive if bad and very valuable if good.

### Response Policy
- [ ] **Respond to every review ≤ 3 stars** within 48 hours
- [ ] **Respond to every 4–5 star review** that includes specific feedback (not just "Great app!")
- [ ] **Ignore spam / obvious competitor reviews** but report them to Apple when clearly abusive

### Response Templates
Draft 5–6 reusable templates in a `plans/review-response-templates.md` file:
- [ ] **Bug report reply** — thank, acknowledge, ask for reproduction details via support email, promise fix
- [ ] **Feature request reply** — thank, note it for roadmap, explain Tier 1 priorities
- [ ] **Pricing complaint** — thank, explain free tier value, reference lifetime option as one-time alternative
- [ ] **Confused new user** — thank, point to templates, offer direct support
- [ ] **Generic positive** — thank, invite follow-up feedback
- [ ] **Misleading negative** — factually correct with dignity, no defensiveness

### Who Watches
- [ ] **You, daily for the first 2 weeks.** App Store Connect notifications are unreliable — log in and check manually.
- [ ] After week 2, weekly cadence unless Sentry flags a crash wave.

---

## 4. Support Workflow

### Email Pipeline
- [ ] **`support@makermargins.com`** receives all support inquiries (configured during Epic 7 landing page setup)
- [ ] **Triage SLA:** first response within 24 hours during first month, 48 hours thereafter
- [ ] **Classification:**
  - Bug → create Sentry-linked GitHub issue, reply with acknowledgment + ETA
  - Feature request → log in a `plans/feature-requests.md` backlog, reply with thank-you and note that it's tracked
  - Billing issue → direct to Apple (Apple handles all subscription refunds), offer help if they're confused about how
  - Usage question → answer directly, log the question for the FAQ

### FAQ Document
- [ ] Build [plans/faq.md](plans/faq.md) from real support questions over the first month
- [ ] Promote frequent questions to the landing page or in-app help
- [ ] Candidate early FAQs:
  - "What can I do on the free tier?"
  - "How do I restore my purchase on a new device?"
  - "Why is the Shopify tab locked?"
  - "Can I export my data?"
  - "Do you have an Android version?" (no, not yet — see [CLAUDE.md](CLAUDE.md) cross-platform future)

### Support Ticket → Code Pipeline
- [ ] Bug report → Sentry issue (if reproducible) → GitHub issue → prioritize → fix → release
- [ ] Feature request → `feature-requests.md` → quarterly review → promote to sub-plan if greenlit

---

## 5. Update Cadence & Release Management

### Initial Cadence
- [ ] **First 4 weeks:** weekly bug-fix releases (1.0.1, 1.0.2, etc.) to respond quickly to real-world issues
- [ ] **Weeks 5–12:** biweekly cadence
- [ ] **Month 4+:** monthly feature releases (1.1.0, 1.2.0) + ad-hoc hotfixes

### Release Notes Convention
- [ ] **Format:** user-facing changelog grouped by "New," "Improved," "Fixed"
- [ ] **Tone:** plain language, no jargon, no apology-heavy writing
- [ ] **Length:** 3–6 bullets max
- [ ] **Hosted:** in App Store Connect release notes + mirrored on landing page `/changelog` page

### Phased Release (Always On)
- [ ] **Every update uses phased release**, not just 1.0
- [ ] 7-day rollout: 1% → 2% → 5% → 10% → 20% → 50% → 100%
- [ ] Pause at any phase if Sentry shows elevated crash rate

### Version Number Discipline
- [ ] **Semver-ish:** `MAJOR.MINOR.PATCH`
  - MAJOR: breaking UI changes or major new epic features
  - MINOR: new features, substantial improvements
  - PATCH: bug fixes, small improvements
- [ ] **Build number:** always increment, never reused, even for TestFlight-only builds

---

## 6. Launch Marketing

### Launch Day Plan
- [ ] **Day of week:** Tuesday or Wednesday (highest press coverage, best Product Hunt momentum)
- [ ] **Time of day:** 12:01 AM Pacific if going for Product Hunt, else 6–9 AM Pacific for US press cycle
- [ ] **Release strategy:** manual release in App Store Connect, not automatic — coordinate with landing page updates and social posts

### Product Hunt
- [ ] **Launch on Product Hunt** — free, high-traffic, indie-friendly
- [ ] **Preparation (1–2 weeks before):**
  - Teaser page on Product Hunt with email capture
  - Gallery images (same annotated screenshots from App Store)
  - Hunter (someone with PH karma who submits for you) — or self-submit
  - First comment prepared (your launch story, not just "check it out")
- [ ] **Launch day:**
  - Post at 12:01 AM Pacific
  - Share on Twitter/X, LinkedIn, maker Discord/Slacks
  - Respond to every comment personally
  - Goal: top 5 product of the day

### Reddit Seeding
- [ ] **Subreddits to consider** (follow rules carefully — some ban self-promo):
  - r/Etsy — biggest audience, strict rules, often allow "made a thing for X problem" posts
  - r/woodworking — friendly, show the woodworking use case
  - r/resin, r/leathercraft, r/candlemaking — craft-specific communities
  - r/smallbusiness — broader audience
  - r/EtsySellers — pricing questions are constant here, natural fit
  - r/crafts, r/handmade — general maker audiences
  - r/indiehackers — tech-audience that loves indie dev launches
  - r/iOSProgramming — dev community, for the technical story
- [ ] **Approach:** not "here's my app" posts. Share the problem you solved, your research into it, and mention the app in context. Authentic > promotional.
- [ ] **Do NOT spam cross-post.** One subreddit per day, different framing for each.

### Maker Community Outreach
- [ ] YouTube woodworkers with ≤100K subs (more receptive than bigger channels)
- [ ] Etsy shop owners with active communities
- [ ] Maker-focused newsletters (The Maker's Yield, Makers Muse, etc.)
- [ ] Craft podcast guest opportunities

### Press Outreach
- [ ] Target publications (realistic for indie launch):
  - 9to5Mac
  - MacRumors (Apps section)
  - The Sweet Setup
  - Indie Apps Catalog
  - iPhone Life
  - Cult of Mac
- [ ] **Press kit:** zip file with high-res screenshots, icon, app description, founder photo + bio, contact info, embargo date
- [ ] **Email pitch template:** personalized, 3 paragraphs max, include press kit link
- [ ] **Timing:** send embargo-tagged pitches 1 week before launch

### Landing Page Email Capture
- [ ] Add email signup form on landing page ("Get notified when MakerMargins launches")
- [ ] Use the captured list for a single launch-day announcement email
- [ ] Tool: Buttondown, EmailOctopus, or Mailchimp free tier — nothing fancy needed
- [ ] One-time use initially; can convert to ongoing newsletter if desired

### Social Content
- [ ] **Twitter/X:** 1 tweet per major feature in the week leading up, launch day thread with screenshots and the story
- [ ] **LinkedIn:** longer post about the problem and why makers are underpaid (play to the business audience)
- [ ] **Instagram/TikTok:** skip unless you already have presence — video content production cost is too high for ROI at launch

---

## 7. Ongoing ASO (App Store Optimization)

### Keyword Iteration
- [ ] Monitor **App Store Connect → Analytics → Search Terms** weekly for the first month
- [ ] Track which keywords drive installs vs. which are wasted space
- [ ] Iterate the keyword field monthly (update doesn't require app resubmission if only metadata)
- [ ] Consider tools post-launch if budget allows: **AppFollow** ($49/mo), **Sensor Tower** (enterprise pricing, skip), or free alternatives like **App Radar**

### Screenshot Optimization
- [ ] Apple supports A/B testing of screenshots via **Product Page Optimization** in App Store Connect (free)
- [ ] Test hero screenshot variations (annotated vs. clean, different feature emphasis)
- [ ] Run tests for 2–4 weeks minimum for statistical significance

### Localized Listings (Expansion)
- [ ] After 2–3 months of EU traffic data, localize the App Store listing into:
  - German (biggest EU market)
  - French
  - Spanish
  - Italian
  - Dutch
- [ ] **Don't localize the app UI yet** — just the listing. Listings-only localization is a Fiverr job (~$20–50 per language).
- [ ] Measure install lift per market before deciding on full UI localization.

### In-App Review Prompts
- [ ] Use `SKStoreReviewController.requestReview()` at positive moments
- [ ] **Triggers:** after `purchaseSucceeded`, after 5 successful `stopwatchCompleted` events, after `portfolioViewed` with 3+ products. **Never** after an error.
- [ ] Apple limits this to 3 prompts per year per user, enforced system-wide.

---

## 8. Financial & LLC Operational Hygiene

### Banking
- [ ] **LLC business checking account** confirmed open with bank; account and routing numbers ready for App Store Connect Agreements/Banking
- [ ] **App Store payouts** hit this account on Apple's schedule (~45 days after end of month, minimum payout threshold $150 USD equivalent)
- [ ] **EU payouts** same account, Apple converts to USD unless you set up per-currency accounts

### Bookkeeping Integration
- [ ] Add "MakerMargins app revenue" as a separate line item in LLC bookkeeping (QuickBooks, Wave, Xero, whatever the woodworking business uses)
- [ ] **Chart of accounts:**
  - Income: App Store Revenue (US), App Store Revenue (EU)
  - Expenses: Apple Developer Program fee, Domain registration, Carrd, Google Workspace, vendor subscriptions (if any paid tiers are hit)
- [ ] **Reconcile monthly** against App Store Connect statements

### Taxes
- [ ] **Quarterly estimated taxes** — add app revenue to the LLC's quarterly calc. Don't wait for year-end.
- [ ] **1099-K from Apple** — issued in January for prior year if revenue >$600. Include in annual tax filing.
- [ ] **Sales tax:** Apple handles US state sales tax where applicable. No action needed.
- [ ] **VAT:** Apple is merchant of record in EU. No action needed.
- [ ] **Self-employment tax:** if LLC is a single-member LLC (pass-through), revenue is self-employment income and subject to SE tax.

### Expense Tracking (Annual)
Minimum yearly costs to budget for:
- Apple Developer Program: **$99**
- Domain (Cloudflare): **~$10**
- Carrd Pro: **$19**
- Google Workspace (optional): **$72** ($6/mo)
- PostHog: **$0** (1M events/mo free tier)
- Sentry: **$0** (5K errors free tier)
- RevenueCat: **$0** (free until $2.5k MTR)
- **Total: ~$130–200/year** baseline

Revenue breakeven is roughly 5–10 lifetime sales or 10–20 annual subscribers per year. Very low bar.

### Backup & Security
- [ ] **Apple ID 2FA backup codes** stored in password manager (1Password, Bitwarden, etc.) — NOT on one device only
- [ ] **App Store Connect API key (.p8 file)** backed up in encrypted storage
- [ ] **Distribution certificate + provisioning profile** backed up as base64 secrets in GitHub (already used by CI release workflow)
- [ ] **D-U-N-S number, EIN, LLC state registration** documents accessible from a secondary location (not just the primary laptop)
- [ ] **GitHub account 2FA** with backup codes stored separately
- [ ] **RevenueCat, PostHog, Sentry account credentials** in password manager

---

## 9. Feature Flags & Experiments

PostHog feature flags are available on the free tier and were installed in Epic 7 but not actively used. Epic 8 activates them.

### Launch Experiments
- [ ] **Paywall copy A/B test** — variant headlines, feature bullet ordering, pricing layout
- [ ] **Free tier product cap** — test 3 vs. 2 vs. 5 products to find the conversion sweet spot
- [ ] **Free tier product cap** — test 3 vs. 2 vs. 5 products to find the conversion sweet spot
- [ ] **Onboarding variations** — template picker auto-open vs. dismissible vs. full-screen

### Staged Rollouts for Risky Features
- [ ] Any new major feature gates behind a PostHog flag and rolls out 10% → 50% → 100% over 2 weeks
- [ ] Lets you kill a feature instantly if it causes regressions

---

## 10. Community Building (Low Priority, Evaluate at Month 3)

- [ ] **Discord/Slack for users?** Only if organic demand emerges — don't force it.
- [ ] **Newsletter?** Convert the launch email list into a monthly update if there's enough news to share.
- [ ] **Public roadmap?** Consider a simple public page (Canny, Nolt, or a GitHub Projects board) to let users vote on features.
- [ ] **Changelog page** on landing page — mirrored from App Store release notes, good SEO.

---

## 11. Long-Term Growth Levers (Month 6+)

Not for launch, but worth tracking so they don't get forgotten:

- [ ] **Android port** — see [CLAUDE.md](../CLAUDE.md) cross-platform future. All architectural prep already done in Epic 7.
- [ ] **Web version** — same. Supabase backend activates when this happens.
- [ ] **Tier 1 roadmap features** (Sales Tracking, Overhead Allocation, Reports, Inventory) — from CLAUDE.md Future Features table
- [ ] **Wholesale pricing tier** (Tier 2)
- [ ] **Affiliate/partner program** for content creators in the maker space
- [ ] **Team/multi-user mode** — if demand emerges from small businesses with employees

---

## Dependencies & Relationships

- **Blocked by** [epic7-production-launch.md](epic7-production-launch.md) completion — nothing in Epic 8 starts until the app is live on the App Store.
- **Informs** the post-launch roadmap beyond Tier 1 features in CLAUDE.md.
- **Uses** all the vendor infrastructure set up in Epic 7 (PostHog, Sentry, RevenueCat, landing page, support email).

---

## Scope Note

This Epic is deliberately broad and high-level because many of its concrete tasks can't be planned until real production data exists. Each section should expand into its own sub-plan (or discrete task) once Epic 7 ships and the first week of real-world data is in hand. Treat this file as the **index of everything you promised yourself you'd do after launch** — review it monthly post-launch and convert active items into tracked work.
