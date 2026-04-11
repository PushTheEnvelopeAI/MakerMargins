// SettingsView.swift
// MakerMargins
//
// Tab 3 root. App-level settings:
//   - Currency selector (USD / EUR) — Epic 1
//   - Default labor rate — Epic 2
//   - Categories management — Epic 1
//   - Platform Fee Profiles — Epic 4

import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.currencyFormatter) private var currencyFormatter
    @Environment(\.appearanceManager) private var appearanceManager
    @Environment(\.laborRateManager) private var laborRateManager
    @Environment(\.entitlementManager) private var entitlementManager
    @Environment(\.analyticsManager) private var analyticsManager

    @State private var laborRateText: String = ""
    @State private var showPaywall = false
    @State private var paywallReason: PaywallReason = .manual
    @State private var showPrivacyDisclosure = false
    @FocusState private var laborRateFocused: Bool

    var body: some View {
        // @Bindable lets us derive bindings from @Observable objects
        // sourced from the environment — the Apple-recommended pattern.
        @Bindable var formatter = currencyFormatter
        @Bindable var appearance = appearanceManager

        List {
            // MARK: - Pro
            Section {
                if entitlementManager.isPro {
                    switch entitlementManager.activeEntitlement {
                    case .annual:
                        Label("Pro — Annual", systemImage: "crown.fill")
                            .foregroundStyle(AppTheme.Colors.accent)
                        Button("Manage Subscription") {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                Task {
                                    try? await AppStore.showManageSubscriptions(in: windowScene)
                                }
                            }
                        }
                    case .lifetime:
                        Label("Pro — Lifetime", systemImage: "crown.fill")
                            .foregroundStyle(AppTheme.Colors.accent)
                    case .none:
                        EmptyView()
                    }
                } else {
                    Button {
                        paywallReason = .manual
                        showPaywall = true
                    } label: {
                        Label("Upgrade to Pro", systemImage: "crown")
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                }

                Button("Restore Purchases") {
                    Task {
                        try? await entitlementManager.restorePurchases()
                    }
                }
            } header: {
                Text("MakerMargins Pro")
            }

            Section("Display") {
                Picker("Currency", selection: $formatter.selected) {
                    ForEach(Currency.allCases) { currency in
                        Text(currency.displayName).tag(currency)
                    }
                }

                Picker("Appearance", selection: $appearance.setting) {
                    ForEach(AppearanceSetting.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.icon).tag(mode)
                    }
                }
            }

            Section {
                HStack {
                    Text("Hourly Rate")
                    Spacer()
                    CurrencyInputField(symbol: currencyFormatter.symbol, text: $laborRateText, suffix: "/hr")
                        .focused($laborRateFocused)
                        .onSubmit { commitLaborRate() }
                        .onChange(of: laborRateFocused) { _, focused in
                            if !focused { commitLaborRate() }
                        }
                }
            } header: {
                Text("Your Hourly Rate")
            } footer: {
                Text("What you pay yourself per hour. New work steps will use this rate — you can override it per step.")
            }

            Section {
                NavigationLink {
                    PlatformPricingDefaultFormView()
                } label: {
                    Label("Pricing Defaults", systemImage: "dollarsign.circle")
                }
            } header: {
                Text("Selling")
            } footer: {
                Text("Set default fees and profit margins. These pre-fill editable fields across all platform tabs. You can override per product.")
            }

            // MARK: - Privacy
            Section {
                Toggle("Share Anonymous Usage Data", isOn: Binding(
                    get: { analyticsManager.isEnabled },
                    set: { analyticsManager.setEnabled($0) }
                ))

                Button("What We Collect") {
                    showPrivacyDisclosure = true
                }

                Link("Privacy Policy", destination: URL(string: "https://makermargins.app/privacy")!)
                Link("Terms of Use", destination: URL(string: "https://makermargins.app/terms")!)
            } header: {
                Text("Privacy")
            } footer: {
                Text("Anonymous crash reports and usage events help us improve the app. We never send your product data, costs, or labor times.")
            }
        }
        .onAppear {
            laborRateText = "\(laborRateManager.defaultRate)"
            analyticsManager.signal(.settingsOpened)
        }
        .onChange(of: currencyFormatter.selected) { _, newValue in
            analyticsManager.signal(.currencyChanged, payload: ["currency": newValue.rawValue.lowercased()])
        }
        .onChange(of: appearanceManager.setting) { _, newValue in
            analyticsManager.signal(.appearanceChanged, payload: ["mode": newValue.rawValue.lowercased()])
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { laborRateFocused = false }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: paywallReason)
        }
        .sheet(isPresented: $showPrivacyDisclosure) {
            NavigationStack {
                List {
                    Section("What we send") {
                        Label("Crash reports (anonymous)", systemImage: "exclamationmark.triangle")
                        Label("Usage events (which features you use)", systemImage: "chart.bar")
                        Label("Purchase events", systemImage: "creditcard")
                    }
                    Section("What we never send") {
                        Label("Product names or descriptions", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                        Label("Costs, prices, or labor times", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                        Label("Supplier information", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                        Label("Any data you've entered", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Data Collection")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showPrivacyDisclosure = false }
                    }
                }
            }
        }
    }

    private func commitLaborRate() {
        if let value = Decimal(string: laborRateText), value >= 0 {
            laborRateManager.defaultRate = value
        }
    }
}
