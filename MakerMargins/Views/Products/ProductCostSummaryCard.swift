// ProductCostSummaryCard.swift
// MakerMargins
//
// Reusable card showing the cost breakdown for a Product.
// Epic 1: shipping cost is live; all other lines show $0.00 until
// CostingEngine is implemented in Epic 2.

import SwiftUI

struct ProductCostSummaryCard: View {
    let product: Product
    @Environment(\.currencyFormatter) private var formatter

    var body: some View {
        GroupBox("Cost Summary") {
            VStack(spacing: 0) {
                costRow(label: "Labor", value: 0, note: "Available in Epic 2")
                Divider()
                costRow(label: "Materials", value: 0, note: "Available in Epic 3")
                Divider()
                costRow(label: "Shipping", value: product.shippingCost)
                Divider()
                costRow(label: "Total Production Cost", value: product.shippingCost, bold: true)
            }
        }
    }

    @ViewBuilder
    private func costRow(label: String, value: Decimal, note: String? = nil, bold: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(bold ? .subheadline.weight(.semibold) : .subheadline)
                if let note {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(formatter.format(value))
                .font(bold ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(bold ? .primary : .secondary)
        }
        .padding(.vertical, 8)
    }
}
