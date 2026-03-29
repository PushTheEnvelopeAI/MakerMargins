// ProductCostSummaryCard.swift
// MakerMargins
//
// Reusable card showing the cost breakdown for a Product.
// Labor and total production cost use CostingEngine (Epic 2).
// Materials stub remains until Epic 3.

import SwiftUI

struct ProductCostSummaryCard: View {
    let product: Product
    @Environment(\.currencyFormatter) private var formatter

    var body: some View {
        GroupBox("Cost Summary") {
            VStack(spacing: 0) {
                costRow(label: "Labor", value: CostingEngine.totalLaborCost(product: product))
                Divider()
                costRow(label: "Materials", value: 0, note: "Available in Epic 3")
                Divider()
                costRow(label: "Shipping", value: product.shippingCost)
                Divider()
                costRow(label: "Total Production Cost", value: CostingEngine.totalProductionCost(product: product), bold: true)
            }
        }
    }

    @ViewBuilder
    private func costRow(label: String, value: Decimal, note: String? = nil, bold: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(bold ? AppTheme.Typography.sectionHeader : AppTheme.Typography.bodyText)
                if let note {
                    Text(note)
                        .font(AppTheme.Typography.note)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(formatter.format(value))
                .font(bold ? AppTheme.Typography.sectionHeader : AppTheme.Typography.bodyText)
                .foregroundStyle(bold ? .primary : .secondary)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}
