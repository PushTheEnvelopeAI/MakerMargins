// PortfolioView.swift
// MakerMargins
//
// Portfolio-level product comparison view. Ranks all products side-by-side
// on key financial metrics — earnings, profitability, cost structure.
// Pushed from ProductListView toolbar within the same NavigationStack.
// Epic 6.

import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Query(sort: \Product.title) private var products: [Product]
    @Environment(\.currencyFormatter) private var formatter

    // MARK: - State

    @State private var selectedPlatform: PlatformType = .general
    @State private var sortMetric: SortMetric = .earnings

    private enum SortMetric: String, CaseIterable {
        case earnings = "Earnings"
        case profitMargin = "Margin"
        case hourlyRate = "$/Hour"
        case productionCost = "Cost"
    }

    // MARK: - Body

    var body: some View {
        Group {
            if products.isEmpty {
                ContentUnavailableView(
                    "No Products Yet",
                    systemImage: "chart.bar.xaxis.ascending",
                    description: Text("Create products and set prices to compare your portfolio.")
                )
            } else {
                portfolioContent
            }
        }
        .navigationTitle("Portfolio")
        .appBackground()
    }

    /// Main scrollable content. Computes snapshots once and threads the array
    /// through all sections to avoid redundant CostingEngine calls.
    private var portfolioContent: some View {
        let snapshots = buildSortedSnapshots()
        let priced = snapshots.filter { $0.hasPricing }
        let unpriced = snapshots.filter { !$0.hasPricing }
        let avg = CostingEngine.portfolioAverages(snapshots: snapshots)

        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                platformPicker
                portfolioSummaryCard(avg: avg, priced: priced)
                sortPicker

                if priced.isEmpty {
                    noPricingHint
                } else {
                    earningsLeaderboard(priced: priced, unpriced: unpriced)
                    profitabilitySection(priced: priced)
                }

                costBreakdownSection(snapshots: snapshots)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    /// Builds and sorts snapshots once per render cycle.
    private func buildSortedSnapshots() -> [CostingEngine.ProductSnapshot] {
        let all = CostingEngine.portfolioSnapshots(products: products, platform: selectedPlatform)
        switch sortMetric {
        case .earnings:
            return all.sorted { $0.earnings > $1.earnings }
        case .profitMargin:
            return all.sorted { ($0.profitMargin ?? Decimal(-999)) > ($1.profitMargin ?? Decimal(-999)) }
        case .hourlyRate:
            return all.sorted { ($0.hourlyRate ?? Decimal(-999)) > ($1.hourlyRate ?? Decimal(-999)) }
        case .productionCost:
            return all.sorted { $0.productionCost > $1.productionCost }
        }
    }

    // MARK: - Platform & Sort Pickers

    private var platformPicker: some View {
        Picker("Platform", selection: $selectedPlatform) {
            ForEach(PlatformType.allCases, id: \.self) { platform in
                Text(platform.rawValue).tag(platform)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortPicker: some View {
        Picker("Sort by", selection: $sortMetric) {
            ForEach(SortMetric.allCases, id: \.self) { metric in
                Text(metric.rawValue).tag(metric)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Card

    private func portfolioSummaryCard(
        avg: (avgEarnings: Decimal, avgProfitMargin: Decimal?,
              avgHourlyRate: Decimal?, pricedCount: Int, totalCount: Int),
        priced: [CostingEngine.ProductSnapshot]
    ) -> some View {
        let top = priced.max(by: { $0.earnings < $1.earnings })
        let worst = priced.min(by: { $0.earnings < $1.earnings })

        return GroupBox {
            VStack(spacing: AppTheme.Spacing.sm) {
                CalculatorSectionHeader(title: "Portfolio Overview", icon: "chart.pie")

                DetailRow(label: "Products Priced", value: "\(avg.pricedCount) of \(avg.totalCount)")

                HStack {
                    Text("Avg. Earnings / Sale")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    Text(formatter.format(avg.avgEarnings))
                        .font(AppTheme.Typography.heroPrice)
                        .foregroundStyle(avg.avgEarnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive)
                }

                if let margin = avg.avgProfitMargin {
                    DetailRow(label: "Avg. Profit Margin", value: PercentageFormat.toDisplay(margin) + "%")
                }

                if let rate = avg.avgHourlyRate {
                    DetailRow(label: "Avg. Hourly Rate", value: formatter.format(rate) + "/hr")
                }

                if top != nil || (worst != nil && worst!.earnings < 0) {
                    Divider()
                }

                if let top {
                    calloutRow(
                        icon: "trophy.fill",
                        color: AppTheme.Colors.accent,
                        label: "Top Earner",
                        product: top.product.title,
                        value: formatter.format(top.earnings)
                    )
                }

                if let worst, worst.earnings < 0 {
                    calloutRow(
                        icon: "exclamationmark.triangle.fill",
                        color: AppTheme.Colors.destructive,
                        label: "Needs Attention",
                        product: worst.product.title,
                        value: formatter.format(worst.earnings)
                    )
                }
            }
        }
        .heroCardStyle()
    }

    private func calloutRow(icon: String, color: Color,
                            label: String, product: String,
                            value: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.secondary)
                Text(product)
                    .font(AppTheme.Typography.bodyText)
                    .lineLimit(1)
            }
            Spacer()
            Text(value)
                .font(AppTheme.Typography.sectionHeader)
                .foregroundStyle(color)
        }
    }

    // MARK: - Earnings Leaderboard

    private func earningsLeaderboard(
        priced: [CostingEngine.ProductSnapshot],
        unpriced: [CostingEngine.ProductSnapshot]
    ) -> some View {
        let maxVal = priced.map { $0.earnings }.max() ?? 0

        return GroupBox {
            VStack(spacing: AppTheme.Spacing.xs) {
                CalculatorSectionHeader(title: "Earnings / Sale", icon: "trophy")

                ForEach(priced, id: \.product.persistentModelID) { snap in
                    NavigationLink(value: snap.product) {
                        portfolioBarRow(
                            imageData: snap.product.image,
                            title: snap.product.title,
                            value: formatter.format(snap.earnings),
                            proportion: proportion(snap.earnings, max: maxVal),
                            barColor: snap.earnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive,
                            valueColor: snap.earnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive
                        )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(unpriced, id: \.product.persistentModelID) { snap in
                    NavigationLink(value: snap.product) {
                        HStack(spacing: AppTheme.Spacing.md) {
                            ProductThumbnailView(imageData: snap.product.image, size: 32)
                            Text(snap.product.title)
                                .font(AppTheme.Typography.bodyText)
                                .lineLimit(1)
                            Spacer()
                            Text("No \(selectedPlatform.rawValue) price")
                                .font(AppTheme.Typography.note)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, AppTheme.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .backgroundStyle(AppTheme.Colors.pricingSurface)
    }

    // MARK: - Profitability

    private func profitabilitySection(priced: [CostingEngine.ProductSnapshot]) -> some View {
        let withMargin = priced.filter { $0.profitMargin != nil }
        let withRate = priced.filter { $0.hourlyRate != nil }
        let noHours = priced.filter { $0.hourlyRate == nil }
        let maxMarginVal = withMargin.compactMap { $0.profitMargin }.max() ?? 0
        let maxRateVal = withRate.compactMap { $0.hourlyRate }.max() ?? 0

        return GroupBox {
            VStack(spacing: AppTheme.Spacing.xs) {
                CalculatorSectionHeader(title: "Profitability", icon: "percent")

                // Sub-group: Profit Margin
                Text("Profit Margin")
                    .font(AppTheme.Typography.sectionLabel)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(withMargin, id: \.product.persistentModelID) { snap in
                    if let margin = snap.profitMargin {
                        NavigationLink(value: snap.product) {
                            portfolioBarRow(
                                imageData: snap.product.image,
                                title: snap.product.title,
                                value: PercentageFormat.toDisplay(margin) + "%",
                                proportion: proportion(margin, max: maxMarginVal),
                                barColor: margin >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive,
                                valueColor: margin >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .padding(.vertical, AppTheme.Spacing.xs)

                // Sub-group: Effective Hourly Rate
                Text("Effective Hourly Rate")
                    .font(AppTheme.Typography.sectionLabel)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(withRate, id: \.product.persistentModelID) { snap in
                    if let rate = snap.hourlyRate {
                        NavigationLink(value: snap.product) {
                            portfolioBarRow(
                                imageData: snap.product.image,
                                title: snap.product.title,
                                value: formatter.format(rate) + "/hr",
                                proportion: proportion(rate, max: maxRateVal),
                                barColor: rate >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive,
                                valueColor: rate >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                ForEach(noHours, id: \.product.persistentModelID) { snap in
                    HStack(spacing: AppTheme.Spacing.md) {
                        ProductThumbnailView(imageData: snap.product.image, size: 32)
                        Text(snap.product.title)
                            .font(AppTheme.Typography.bodyText)
                            .lineLimit(1)
                        Spacer()
                        Text("N/A")
                            .font(AppTheme.Typography.note)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                }
            }
        }
        .backgroundStyle(AppTheme.Colors.pricingSurface)
    }

    // MARK: - Cost Breakdown

    private func costBreakdownSection(snapshots: [CostingEngine.ProductSnapshot]) -> some View {
        GroupBox {
            VStack(spacing: AppTheme.Spacing.xs) {
                CalculatorSectionHeader(title: "Cost Breakdown", icon: "chart.bar")

                ForEach(snapshots, id: \.product.persistentModelID) { snap in
                    NavigationLink(value: snap.product) {
                        costBreakdownRow(snap: snap)
                    }
                    .buttonStyle(.plain)
                }

                legendRow
            }
        }
        .backgroundStyle(AppTheme.Colors.pricingSurface)
    }

    @ViewBuilder
    private func costBreakdownRow(snap: CostingEngine.ProductSnapshot) -> some View {
        let total = snap.productionCost
        let lFrac = total > 0
            ? CGFloat(NSDecimalNumber(decimal: snap.laborCostBuffered / total).doubleValue) : 0
        let mFrac = total > 0
            ? CGFloat(NSDecimalNumber(decimal: snap.materialCostBuffered / total).doubleValue) : 0
        let sFrac = total > 0
            ? CGFloat(NSDecimalNumber(decimal: snap.shippingCost / total).doubleValue) : 0

        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.md) {
                ProductThumbnailView(imageData: snap.product.image, size: 32)
                Text(snap.product.title)
                    .font(AppTheme.Typography.bodyText)
                    .lineLimit(1)
                Spacer()
                Text(formatter.format(snap.productionCost))
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(AppTheme.Colors.accent.opacity(0.5))
                        .frame(width: geo.size.width * lFrac)
                    Rectangle().fill(AppTheme.Colors.categoryBadge.opacity(0.5))
                        .frame(width: geo.size.width * mFrac)
                    Rectangle().fill(AppTheme.Colors.secondaryButton.opacity(0.3))
                        .frame(width: geo.size.width * sFrac)
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cost: \(formatter.format(snap.productionCost))")
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private var legendRow: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            legendDot(color: AppTheme.Colors.accent.opacity(0.5), label: "Labor")
            legendDot(color: AppTheme.Colors.categoryBadge.opacity(0.5), label: "Materials")
            legendDot(color: AppTheme.Colors.secondaryButton.opacity(0.3), label: "Shipping")
        }
        .font(AppTheme.Typography.note)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, AppTheme.Spacing.xs)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    // MARK: - Empty States

    private var noPricingHint: some View {
        ContentUnavailableView(
            "No \(selectedPlatform.rawValue) Prices Set",
            systemImage: "tag",
            description: Text("Set actual prices on the \(selectedPlatform.rawValue) tab in each product's Price section to see earnings and profitability.")
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private func portfolioBarRow(
        imageData: Data?,
        title: String,
        value: String,
        proportion: CGFloat,
        barColor: Color,
        valueColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.md) {
                ProductThumbnailView(imageData: imageData, size: 32)
                Text(title)
                    .font(AppTheme.Typography.bodyText)
                    .lineLimit(1)
                Spacer()
                Text(value)
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(valueColor)
            }

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(barColor.opacity(0.3))
                    .frame(width: max(geo.size.width * proportion, 2), height: 6)
            }
            .frame(height: 6)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private func proportion(_ value: Decimal, max: Decimal) -> CGFloat {
        guard max > 0 else { return 0 }
        let raw = CGFloat(NSDecimalNumber(decimal: value / max).doubleValue)
        return Swift.min(Swift.max(raw, 0), 1)
    }
}
