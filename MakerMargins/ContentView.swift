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
    var body: some View {
        TabView {
            NavigationStack {
                ProductListView()
            }
            .tabItem {
                Label("Products", systemImage: "square.grid.2x2")
            }

            NavigationStack {
                WorkshopView()
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
    }
}
