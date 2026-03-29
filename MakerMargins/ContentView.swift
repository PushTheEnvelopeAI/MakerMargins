// ContentView.swift
// MakerMargins
//
// Root 3-tab navigation shell.
// This view owns only the TabView structure — no state, no queries.
// Each tab root owns its own NavigationStack and data queries.
//
// Tabs:
//   1. Products  (square.grid.2x2) — ProductListView    — Epic 1
//   2. Workshop  (timer)           — WorkshopView       — Epic 2
//   3. Settings  (gearshape)       — SettingsView       — Epic 1
//
// Epic 0 — placeholder tab destinations until each Epic is implemented.

import SwiftUI

struct ContentView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        TabView {
            NavigationStack {
                ProductListView()
            }
            .tabItem {
                Label("Products", systemImage: "square.grid.2x2")
            }

            NavigationStack {
                Text("Workshop coming in Epic 2")
                    .navigationTitle("Workshop")
            }
            .tabItem {
                Label("Workshop", systemImage: "timer")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(theme.accent)
    }
}
