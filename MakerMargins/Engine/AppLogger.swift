// AppLogger.swift
// MakerMargins
//
// Thin facade over os.Logger providing categorised logging across the app.
// Caseless enum (matches CostingEngine pattern) — pure static API, no instances.
//
// Cross-platform semantics: the call-site API (AppLogger.swiftData.error(...))
// is designed so future Android (Timber/Logcat) and web (console+Sentry)
// implementations can expose the same surface without changing business logic.
//
// Privacy rules:
//   - Never log SwiftData model content with .public (titles, costs, summaries → .private)
//   - Errors: .error level with .public for error type, .private for user data
//   - State transitions: .info level
//   - Verbose traces: .debug level (stripped from release automatically)

import os

enum AppLogger {
    /// Calculation logic (CostingEngine edge cases, division-by-zero guards).
    static let costing = Logger(subsystem: "com.makermargins.app", category: "costing")

    /// SwiftData operations (container init, save failures, migration).
    static let swiftData = Logger(subsystem: "com.makermargins.app", category: "swiftdata")

    /// StoreKit / RevenueCat entitlement operations.
    static let storeKit = Logger(subsystem: "com.makermargins.app", category: "storekit")

    /// View lifecycle and navigation events.
    static let ui = Logger(subsystem: "com.makermargins.app", category: "ui")

    /// App lifecycle (launch, background, terminate, crash recovery).
    static let lifecycle = Logger(subsystem: "com.makermargins.app", category: "lifecycle")

    /// Analytics signal dispatch and opt-out state.
    static let analytics = Logger(subsystem: "com.makermargins.app", category: "analytics")
}
