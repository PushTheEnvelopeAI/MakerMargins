// BatchForecastView.swift
// MakerMargins
//
// Batch forecasting component — projects total labor time, material cost,
// and revenue for a given production run quantity (N units).
// Rendered within the Forecast sub-tab of ProductDetailView.
// Epic 5 — stub.

import SwiftUI

struct BatchForecastView: View {
    let product: Product

    var body: some View {
        ContentUnavailableView(
            "Coming Soon",
            systemImage: "chart.bar.xaxis.ascending",
            description: Text("Batch forecasting will help you plan production runs and project costs.")
        )
        .padding(.horizontal)
    }
}
