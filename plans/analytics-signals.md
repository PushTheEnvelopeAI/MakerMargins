# Analytics Signal Contract

> Cross-platform event vocabulary for MakerMargins product analytics.
> Same signal names and payload keys on iOS, Android, and web.
> PostHog funnels work across all platforms without special handling.
>
> Source of truth: `MakerMargins/Engine/AnalyticsSignal.swift`

---

## Privacy Rules

- Payload values are **enums, small integers, or bucketed ranges** — never free-form user input
- Product counts → buckets: `1`, `2-5`, `6-20`, `20+`
- Prices → excluded entirely or log-scale buckets
- Titles, summaries, supplier URLs, labor rates, material costs: **never sent, ever**

---

## Signals

### Lifecycle
| Signal | Payload | Notes |
|--------|---------|-------|
| `appLaunched` | none | Every launch |
| `firstLaunch` | none | Once, ever |

### Activation Funnel
| Signal | Payload | Notes |
|--------|---------|-------|
| `templateApplied` | `templateId` | Template identifier string |
| `firstProductCreated` | none | Once |
| `firstWorkStepCreated` | none | Once |
| `firstMaterialCreated` | none | Once |
| `firstStopwatchUsed` | none | Once |
| `firstPricingCalculated` | none | Once |
| `portfolioViewed` | none | Every view |

### Feature Usage
| Signal | Payload | Notes |
|--------|---------|-------|
| `productCreated` | none | Every creation |
| `productDuplicated` | none | Every duplication |
| `stopwatchCompleted` | `batchSizeBucket` | Bucketed batch size |
| `batchForecastUsed` | none | Every forecast |
| `platformTabViewed` | `platformType` | general/etsy/shopify/amazon |
| `settingsOpened` | none | Every open |
| `currencyChanged` | `currency` | usd/eur |
| `appearanceChanged` | `mode` | system/light/dark |

### Monetization Funnel
| Signal | Payload | Notes |
|--------|---------|-------|
| `paywallShown` | `reason` | productLimit/platformLocked/manual |
| `paywallDismissed` | none | |
| `trialStarted` | none | |
| `purchaseAttempted` | `productId` | mm_pro_annual/mm_pro_lifetime |
| `purchaseSucceeded` | `productId` | mm_pro_annual/mm_pro_lifetime |
| `purchaseFailed` | `errorCode` | Vendor error code string |
| `restorePurchases` | none | |

### Crash Forwarding
| Signal | Payload | Notes |
|--------|---------|-------|
| `crashDetected` | `exceptionType` | From MetricKit diagnostic payload |

### Error Surfaces
| Signal | Payload | Notes |
|--------|---------|-------|
| `errorEncountered` | `errorDomain` | Error domain only, never user data |
