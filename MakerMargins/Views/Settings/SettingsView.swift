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

    var body: some View {
        // @Bindable lets us derive $formatter.selected from the @Observable
        // currencyFormatter sourced from the environment — the Apple-recommended
        // pattern for binding to @Observable objects obtained via @Environment.
        @Bindable var formatter = currencyFormatter

        List {
            Section("Display") {
                Picker("Currency", selection: $formatter.selected) {
                    ForEach(Currency.allCases) { currency in
                        Text(currency.displayName).tag(currency)
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
        .navigationTitle("Settings")
    }
}
