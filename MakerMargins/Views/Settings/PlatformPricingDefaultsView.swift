// PlatformPricingDefaultsView.swift
// MakerMargins
//
// Lists all four platform types for configuring default pricing values.
// Pushed from SettingsView. Each row navigates to PlatformPricingDefaultFormView.
// No add/delete — all four platforms are always present.

import SwiftUI

struct PlatformPricingDefaultsView: View {
    var body: some View {
        List {
            ForEach(PlatformType.allCases, id: \.self) { platform in
                NavigationLink {
                    PlatformPricingDefaultFormView(platformType: platform)
                } label: {
                    Label(platform.rawValue, systemImage: platform.iconName)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Platform Pricing Defaults")
    }
}
