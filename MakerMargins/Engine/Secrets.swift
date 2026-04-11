import Foundation

/// Vendor API keys for PostHog, Sentry, and RevenueCat.
///
/// Default values are empty strings — the app launches safely with unconfigured
/// secrets (vendor SDKs handle empty keys gracefully by queuing offline or no-oping).
///
/// For production builds, the CI release workflow (.github/workflows/release.yml)
/// overwrites this file with real values from GitHub Secrets before archiving.
/// See plans/epic7-phase1-foundation.md Task 1.14 for the full release workflow.
enum Secrets {
    static let posthogAPIKey = ""
    static let posthogHost = ""
    static let sentryDSN = ""
    static let revenueCatAPIKey = ""
}
