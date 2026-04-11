// AnalyticsManager.swift
// MakerMargins
//
// Product analytics wrapper over PostHog. @Observable, injected via @Environment.
// Follows the existing manager pattern (LaborRateManager, AppearanceManager, CurrencyFormatter).
//
// Privacy:
//   - No PII, no IDFA, no ATT prompt, no autocapture, no session replay
//   - Anonymous install ID only (PostHog default)
//   - User can disable via Settings → Privacy toggle
//   - GDPR-safe: opt-out default-on with no consent dialog required

import Foundation
import PostHog
import SwiftUI

@Observable
final class AnalyticsManager: @unchecked Sendable {

    private(set) var isEnabled: Bool

    init() {
        // Load persisted preference (default: ON)
        self.isEnabled = UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? true

        // Configure PostHog with privacy-safe settings
        let apiKey = Secrets.posthogAPIKey
        guard !apiKey.isEmpty else {
            // No API key configured — skip initialization (dev/CI builds)
            AppLogger.analytics.info("PostHog skipped: no API key configured")
            return
        }

        let config = PostHogConfig(apiKey: apiKey, host: Secrets.posthogHost)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        PostHogSDK.shared.setup(config)

        syncOptState()
        AppLogger.analytics.info("PostHog initialized (enabled: \(self.isEnabled, privacy: .public))")
    }

    /// Send a named analytics signal with an optional string payload.
    /// Early-returns when analytics is disabled by the user.
    func signal(_ name: AnalyticsSignal, payload: [String: String] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(name.rawValue, properties: payload)
    }

    /// Toggle analytics collection. Persists to UserDefaults and syncs PostHog opt state.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "analyticsEnabled")
        syncOptState()
        AppLogger.analytics.info("Analytics \(enabled ? "enabled" : "disabled", privacy: .public) by user")
    }

    private func syncOptState() {
        if isEnabled {
            PostHogSDK.shared.optIn()
        } else {
            PostHogSDK.shared.optOut()
        }
    }
}

// MARK: - Environment Key

struct AnalyticsManagerKey: EnvironmentKey {
    static let defaultValue = AnalyticsManager()
}

extension EnvironmentValues {
    var analyticsManager: AnalyticsManager {
        get { self[AnalyticsManagerKey.self] }
        set { self[AnalyticsManagerKey.self] = newValue }
    }
}
