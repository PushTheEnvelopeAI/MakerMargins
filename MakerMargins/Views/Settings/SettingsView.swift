// SettingsView.swift
// MakerMargins
//
// Tab 3 root. App-level settings:
//   - Currency selector (USD / EUR) — Epic 1
//   - Categories management — Epic 1
//   - Platform Fee Profiles — Epic 4

import SwiftUI

struct SettingsView: View {
    @Environment(\.currencyFormatter) private var currencyFormatter
    @Environment(\.appearanceManager) private var appearanceManager

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

            Section("Products") {
                NavigationLink("Categories") {
                    CategoryListView()
                }
            }

            Section("Selling") {
                NavigationLink("Platform Fee Profiles") {
                    ContentUnavailableView(
                        "Platform Fee Profiles",
                        systemImage: "percent",
                        description: Text("Configure selling platform fees and margin goals. Coming soon.")
                    )
                    .navigationTitle("Platform Fee Profiles")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Settings")
    }
}
