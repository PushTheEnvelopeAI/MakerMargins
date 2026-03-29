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
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Accent bar at top
            theme.accent
                .frame(height: 3)
                .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                HStack {
                    Text("Cost Summary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                }
                .padding(.bottom, 10)

                costRow(label: "Labor", value: 0, note: "Available in Epic 2")
                Divider()
                costRow(label: "Materials", value: 0, note: "Available in Epic 3")
                Divider()
                costRow(label: "Shipping", value: product.shippingCost)
                Divider()
                costRow(label: "Total Production Cost", value: product.shippingCost, bold: true)
            }
            .padding()
        }
        .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: theme.cardCornerRadius))
        .shadow(color: theme.shadowColor, radius: theme.shadowRadius, y: theme.shadowY)
    }

    @ViewBuilder
    private func costRow(label: String, value: Decimal, note: String? = nil, bold: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(bold ? .subheadline.weight(.semibold) : .subheadline)
                    .foregroundStyle(theme.textPrimary)
                if let note {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            Text(formatter.format(value))
                .font(bold ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(bold ? theme.accent : theme.textSecondary)
        }
        .padding(.vertical, 8)
    }
}
