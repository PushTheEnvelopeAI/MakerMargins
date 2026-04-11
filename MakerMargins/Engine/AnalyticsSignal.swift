// AnalyticsSignal.swift
// MakerMargins
//
// Cross-platform event vocabulary for product analytics.
// Same signal names and payload keys will be used on iOS, Android, and web.
// Documented in plans/analytics-signals.md as the canonical contract.
//
// PRIVACY RULES:
//   - Payload values are enums, small integers, or bucketed ranges only
//   - Never send free-form user input, model titles, costs, or supplier info
//   - Product counts use buckets: "1", "2-5", "6-20", "20+"
//   - Prices are excluded entirely or use log-scale buckets

import Foundation

enum AnalyticsSignal: String {

    // MARK: - Lifecycle

    case appLaunched                    // fired every launch
    case firstLaunch                    // fired once, ever

    // MARK: - Activation Funnel (the "aha" moment)

    case templateApplied                // payload: templateId
    case firstProductCreated            // fired once
    case firstWorkStepCreated           // fired once
    case firstMaterialCreated           // fired once
    case firstStopwatchUsed             // fired once
    case firstPricingCalculated         // fired once
    case portfolioViewed                // every view

    // MARK: - Feature Usage

    case productCreated                 // every creation
    case productDuplicated              // every duplication
    case stopwatchCompleted             // payload: batchSizeBucket
    case batchForecastUsed              // every forecast
    case platformTabViewed              // payload: platformType (general/etsy/shopify/amazon)
    case settingsOpened                 // every open
    case currencyChanged                // payload: currency (usd/eur)
    case appearanceChanged              // payload: mode (system/light/dark)

    // MARK: - Monetization Funnel

    case paywallShown                   // payload: reason (productLimit/platformLocked/manual)
    case paywallDismissed               // no payload
    case purchaseAttempted              // payload: productId (mm_pro_annual/mm_pro_lifetime)
    case purchaseSucceeded              // payload: productId
    case purchaseFailed                 // payload: errorCode
    case restorePurchases               // no payload

    // MARK: - Crash Forwarding (MetricKit)

    case crashDetected                  // payload: exceptionType

    // MARK: - Error Surfaces

    case errorEncountered               // payload: errorDomain (never user data)
}
