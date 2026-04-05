// ProductCostSummaryCard.swift
// MakerMargins
//
// Reusable card showing the cost breakdown for a Product.
// Labor and material costs use CostingEngine with per-section buffers.
// Total production cost = labor×(1+laborBuffer) + material×(1+materialBuffer) + shipping.

import SwiftUI

struct ProductCostSummaryCard: View {
    let product: Product
    @Environment(\.currencyFormatter) private var formatter

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            CalculatorSectionHeader(icon: "dollarsign.circle", title: "COST SUMMARY")

            VStack(spacing: 0) {
                costRow(label: "Labor", value: CostingEngine.totalLaborCost(product: product))
                Divider()
                costRow(label: "Materials", value: CostingEngine.totalMaterialCost(product: product))
                Divider()
                costRow(label: "Shipping", value: product.shippingCost)
                Divider()
                costRow(label: "Total Production Cost", value: CostingEngine.totalProductionCost(product: product), bold: true)
            }
            .sectionGroupStyle()
        }
    }

    @ViewBuilder
    private func costRow(label: String, value: Decimal, note: String? = nil, bold: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxxs) {
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
                .foregroundStyle(bold ? AppTheme.Colors.accent : .secondary)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}
