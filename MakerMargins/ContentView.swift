// ContentView.swift
// MakerMargins
//
// Root 4-tab navigation shell.
// This view owns only the TabView structure — no state, no queries.
// Each tab root owns its own NavigationStack and data queries.
//
// Tabs:
//   1. Products   (square.grid.2x2) — ProductListView     — Epic 1
//   2. Labor      (hammer)          — WorkshopView         — Epic 2
//   3. Materials  (shippingbox)     — MaterialsLibraryView — Epic 3 (stub)
//   4. Settings   (gearshape)       — SettingsView         — Epic 1

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ProductListView()
            .tabItem {
                Label("Products", systemImage: "square.grid.2x2")
            }

            WorkshopView()
            .tabItem {
                Label("Labor", systemImage: "hammer")
            }

            MaterialsLibraryView()
            .tabItem {
                Label("Materials", systemImage: "shippingbox")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(AppTheme.Colors.tabTint)
    }
}
