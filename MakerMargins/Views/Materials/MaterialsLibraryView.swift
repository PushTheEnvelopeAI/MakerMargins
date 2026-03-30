// MaterialsLibraryView.swift
// MakerMargins
//
// Tab 3 root — shared materials library.
// Stub view for Epic 3 implementation.

import SwiftUI

struct MaterialsLibraryView: View {
    var body: some View {
        ContentUnavailableView(
            "Materials Library",
            systemImage: "shippingbox",
            description: Text("Track and manage your raw materials here. Coming in Epic 3.")
        )
        .navigationTitle("Materials")
    }
}
