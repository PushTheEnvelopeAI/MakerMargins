// MetricsSubscriber.swift
// MakerMargins
//
// Subscribes to Apple's MetricKit for hardware-level diagnostics that Sentry
// can't capture: thermal state, CPU exceptions, hangs, disk pressure, launch time.
// Forwards crash counts to PostHog as a crashDetected analytics signal.
//
// MetricKit is a system framework — no SPM dependency. iOS-only.
// Supplemental to Sentry, not a replacement.

import Foundation
import MetricKit

final class MetricsSubscriber: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {

    /// Shared instance — kept alive for the app's lifetime.
    nonisolated(unsafe) private static var shared: MetricsSubscriber?

    /// Weak reference to analytics manager for forwarding crash signals.
    /// Set during registration so MetricsSubscriber doesn't own the manager.
    private weak var analyticsManager: AnalyticsManager?

    /// Subscribe to MetricKit. Call once from MakerMarginsApp.init().
    static func register(analyticsManager: AnalyticsManager) {
        let subscriber = MetricsSubscriber()
        subscriber.analyticsManager = analyticsManager
        MXMetricManager.shared.add(subscriber)
        shared = subscriber  // prevent deallocation
        AppLogger.lifecycle.info("MetricKit subscriber registered")
    }

    // MARK: - MXMetricManagerSubscriber

    /// Receives periodic metric payloads (~once per day when the app has been used).
    /// Logs summary stats for launch time, hangs, CPU, and memory.
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let launchTime = payload.applicationLaunchMetrics {
                AppLogger.lifecycle.info("MetricKit launch metrics received: \(launchTime, privacy: .public)")
            }
            AppLogger.lifecycle.info("MetricKit metric payload received (timeStampEnd: \(payload.timeStampEnd, privacy: .public))")
        }
    }

    /// Receives diagnostic payloads containing crash reports, hangs, and disk-write exceptions.
    /// Forwards crash counts to PostHog for monitoring — full stack traces come from Sentry.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            if let crashDiagnostics = payload.crashDiagnostics {
                let count = crashDiagnostics.count
                AppLogger.lifecycle.error("MetricKit: \(count, privacy: .public) crash diagnostic(s) received")

                // Forward crash count to analytics (no stack trace content, just the fact + count)
                analyticsManager?.signal(.crashDetected, payload: [
                    "count": "\(count)",
                    "source": "metrickit"
                ])
            }

            if let hangDiagnostics = payload.hangDiagnostics {
                AppLogger.lifecycle.warning("MetricKit: \(hangDiagnostics.count, privacy: .public) hang diagnostic(s) received")
            }
        }
    }
}
