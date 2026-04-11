// PaywallView.swift
// MakerMargins
//
// Presented as a sheet when the user hits a Pro gate:
//   - Creating a 4th product (scale wall)
//   - Tapping a locked platform tab — Shopify or Amazon (breadth wall)
//   - Tapping "Upgrade to Pro" in Settings (manual)
//
// No free trial. The free tier (3 products, General + Etsy) IS the trial.

import SwiftUI
import RevenueCat

// MARK: - Paywall Reason

enum PaywallReason {
    case productLimit
    case platformLocked(PlatformType)
    case manual

    var headline: String {
        switch self {
        case .productLimit:
            return "You've built 3 products"
        case .platformLocked(let platform):
            return "Unlock \(platform.rawValue) pricing"
        case .manual:
            return "Upgrade to Pro"
        }
    }

    var subheadline: String {
        switch self {
        case .productLimit:
            return "Unlock unlimited products to grow your catalog."
        case .platformLocked:
            return "Compare pricing across all your sales channels."
        case .manual:
            return "Get the most out of MakerMargins."
        }
    }

    var analyticsValue: String {
        switch self {
        case .productLimit: return "productLimit"
        case .platformLocked(let platform): return "platformLocked_\(platform.rawValue.lowercased())"
        case .manual: return "manual"
        }
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    let reason: PaywallReason

    @Environment(\.entitlementManager) private var entitlementManager
    @Environment(\.analyticsManager) private var analyticsManager
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {

                    // MARK: Header
                    headerSection

                    // MARK: Features
                    featuresSection

                    // MARK: Purchase buttons
                    purchaseSection

                    // MARK: Restore
                    restoreSection

                    // MARK: Legal
                    legalSection
                }
                .padding(AppTheme.Spacing.lg)
            }
            .appBackground()
            .navigationTitle("MakerMargins Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: entitlementManager.isPro) { _, isPro in
                if isPro { dismiss() }
            }
            .onAppear {
                analyticsManager.signal(.paywallShown, payload: ["reason": reason.analyticsValue])
            }
            .onDisappear {
                analyticsManager.signal(.paywallDismissed)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.Colors.accent)

            Text(reason.headline)
                .font(AppTheme.Typography.title)
                .multilineTextAlignment(.center)

            Text(reason.subheadline)
                .font(AppTheme.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.Spacing.lg)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            featureRow(icon: "infinity", title: "Unlimited Products", detail: "Track your entire catalog")
            featureRow(icon: "cart.fill", title: "Shopify & Amazon Pricing", detail: "Compare fees across all platforms")
            featureRow(icon: "star.fill", title: "All Future Features", detail: "Sales tracking, reports, inventory & more")
        }
        .cardStyle()
    }

    private var purchaseSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            if entitlementManager.isLoading {
                ProgressView()
                    .padding()
            } else if entitlementManager.availablePackages.isEmpty {
                Text("Unable to load pricing. Please check your connection and try again.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                // Annual button
                if let annual = annualPackage {
                    purchaseButton(
                        package: annual,
                        title: "\(annual.storeProduct.localizedPriceString)/year",
                        subtitle: "Auto-renews annually",
                        badge: nil
                    )
                }

                // Lifetime button
                if let lifetime = lifetimePackage {
                    purchaseButton(
                        package: lifetime,
                        title: "\(lifetime.storeProduct.localizedPriceString) one-time",
                        subtitle: "Pay once, keep forever",
                        badge: "Best Value"
                    )
                }
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    private var restoreSection: some View {
        Button {
            analyticsManager.signal(.restorePurchases)
            Task {
                do {
                    try await entitlementManager.restorePurchases()
                    // If restore succeeded but user still isn't Pro, nothing was found
                    if !entitlementManager.isPro {
                        errorMessage = "No previous purchases found. If you believe this is an error, contact support."
                    }
                } catch {
                    errorMessage = "Could not reach the App Store. Please check your connection and try again."
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.accent)
        }
    }

    private var legalSection: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.md) {
                Link("Terms of Use", destination: URL(string: "https://makermargins.app/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://makermargins.app/privacy")!)
            }
            .font(AppTheme.Typography.caption)
            .foregroundStyle(.secondary)

            Text("Payment is charged through your Apple ID. Annual subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.bodyBold)
                Text(detail)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func purchaseButton(package: Package, title: String, subtitle: String, badge: String?) -> some View {
        Button {
            purchase(package)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.bodyBold)
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.accent.opacity(0.15))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .clipShape(Capsule())
                }

                if isPurchasing {
                    ProgressView()
                        .padding(.leading, 4)
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
        }
        .disabled(isPurchasing)
        .buttonStyle(.plain)
    }

    private func purchase(_ package: Package) {
        guard !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil

        analyticsManager.signal(.purchaseAttempted, payload: ["productId": package.identifier])

        Task {
            do {
                try await entitlementManager.purchase(package: package)
                analyticsManager.signal(.purchaseSucceeded, payload: ["productId": package.identifier])
                // dismiss happens via onChange(of: entitlementManager.isPro)
            } catch {
                analyticsManager.signal(.purchaseFailed, payload: ["errorCode": error.localizedDescription])
                errorMessage = "Purchase could not be completed. Please try again."
            }
            isPurchasing = false
        }
    }

    // MARK: - Package Lookup

    private var annualPackage: Package? {
        entitlementManager.availablePackages.first { $0.packageType == .annual }
    }

    private var lifetimePackage: Package? {
        entitlementManager.availablePackages.first { $0.packageType == .lifetime }
    }
}
