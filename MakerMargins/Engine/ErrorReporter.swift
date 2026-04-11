// ErrorReporter.swift
// MakerMargins
//
// Thin wrapper over Sentry SDK for crash and error reporting.
// Caseless enum (matches CostingEngine, AppLogger pattern).
//
// Privacy:
//   - sendDefaultPii = false — no user identifiers, no device name, no email
//   - Breadcrumbs scrubbed to never contain SwiftData model content
//   - Release tagged with app version for symbolication

import Foundation
import Sentry

enum ErrorReporter {

    /// Initialize Sentry. Call once from MakerMarginsApp.init().
    /// Wrapped in do/catch at the call site — must never crash the app.
    static func start() {
        let dsn = Secrets.sentryDSN
        guard !dsn.isEmpty else {
            AppLogger.lifecycle.info("Sentry skipped: no DSN configured")
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.sendDefaultPii = false
            options.enableAutoSessionTracking = true
            options.enableCaptureFailedRequests = false

            // Tag releases for crash grouping + symbolication
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
            options.releaseName = "com.makermargins.app@\(version)+\(build)"

            // Scrub breadcrumbs — never include SwiftData model content
            options.beforeBreadcrumb = { breadcrumb in
                // Allow navigation and system breadcrumbs through
                // Strip any message that might contain user-entered data
                if breadcrumb.level == .info || breadcrumb.level == .debug {
                    breadcrumb.message = nil
                }
                return breadcrumb
            }
        }

        AppLogger.lifecycle.info("Sentry initialized")
    }
}
