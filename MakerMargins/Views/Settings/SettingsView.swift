// SettingsView.swift
// MakerMargins
//
// Tab 3 root. App-level settings:
//   - Currency selector (USD / EUR) — Epic 1
//   - Default labor rate — Epic 2
//   - Categories management — Epic 1
//   - Platform Fee Profiles — Epic 4

import SwiftUI

struct SettingsView: View {
    @Environment(\.currencyFormatter) private var currencyFormatter
    @Environment(\.appearanceManager) private var appearanceManager
    @Environment(\.laborRateManager) private var laborRateManager

    @State private var laborRateText: String = ""
    @FocusState private var laborRateFocused: Bool

    var body: some View {
        // @Bindable lets us derive bindings from @Observable objects
        // sourced from the environment — the Apple-recommended pattern.
        @Bindable var formatter = currencyFormatter
        @Bindable var appearance = appearanceManager

        List {
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
                    Text("Default Hourly Rate")
                    Spacer()
                    Text(currencyFormatter.symbol)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $laborRateText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: AppTheme.Sizing.inputMedium)
                        .focused($laborRateFocused)
                        .onSubmit { commitLaborRate() }
                        .onChange(of: laborRateFocused) { _, focused in
                            if !focused { commitLaborRate() }
                        }
                    Text("/hr")
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Labor")
            } footer: {
                Text("New work steps will default to this rate. You can adjust the rate per step.")
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
        }
        .onAppear {
            laborRateText = "\(laborRateManager.defaultRate)"
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Settings")
    }

    private func commitLaborRate() {
        if let value = Decimal(string: laborRateText), value >= 0 {
            laborRateManager.defaultRate = value
        }
    }
}
