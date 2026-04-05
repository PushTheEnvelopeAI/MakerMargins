// PortfolioView.swift
// MakerMargins
//
// Portfolio-level product comparison view. Ranks all products side-by-side
// on key financial metrics — earnings, profitability, cost structure.
// Tabs switch which metric's ranking is visible (one section at a time),
// matching the Build/Price/Forecast tab pattern in ProductDetailView.
// Pushed from ProductListView portfolio card within the same NavigationStack.
// Epic 6.

import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Query(sort: \Product.title) private var products: [Product]
    @Environment(\.currencyFormatter) private var formatter

    // MARK: - State

    @State private var selectedPlatform: PlatformType = .general
    @State private var selectedTab: PortfolioTab = .earnings

    private enum PortfolioTab: String, CaseIterable {
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
        let snapshots = CostingEngine.portfolioSnapshots(products: products, platform: selectedPlatform)
        let avg = CostingEngine.portfolioAverages(snapshots: snapshots)

        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                portfolioSummaryCard(avg: avg, snapshots: snapshots)
                tabPicker
                tabContent(snapshots: snapshots)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("View", selection: $selectedTab) {
            ForEach(PortfolioTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Tab Content (one section at a time)

    @ViewBuilder
    private func tabContent(snapshots: [CostingEngine.ProductSnapshot]) -> some View {
        switch selectedTab {
        case .earnings:
            earningsTab(snapshots: snapshots)
        case .profitMargin:
            marginTab(snapshots: snapshots)
        case .hourlyRate:
            hourlyRateTab(snapshots: snapshots)
        case .productionCost:
            costTab(snapshots: snapshots)
        }
    }

    // MARK: - Earnings Tab

    private func earningsTab(snapshots: [CostingEngine.ProductSnapshot]) -> some View {
        let sorted = snapshots.sorted { $0.earnings > $1.earnings }
        let priced = sorted.filter { $0.hasPricing }
        let unpriced = sorted.filter { !$0.hasPricing }
        let maxVal = priced.map { $0.earnings }.max() ?? 0

        return GroupBox {
            VStack(spacing: AppTheme.Spacing.xs) {
                CalculatorSectionHeader(title: "Earnings / Sale", icon: "trophy")

                if priced.isEmpty {
                    noPricingHint
                } else {
                    ForEach(priced, id: \.product.persistentModelID) { snap in
                        NavigationLink { ProductDetailView(product: snap.product) } label: {
                            portfolioBarRow(
                                imageData: snap.product.image,
                                title: snap.product.title,
                                value: CostingEngine.signedProfitPrefix(snap.earnings) + formatter.format(snap.earnings),
                                proportion: proportion(snap.earnings, max: maxVal),
                                barColor: snap.earnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive,
                                valueColor: snap.earnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive,
                                subtitle: secondaryMetrics(margin: snap.profitMargin, hourlyRate: snap.hourlyRate)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    unpricedRows(unpriced)
                }
            }
        }
        .backgroundStyle(AppTheme.Colors.pricingSurface)
    }

    // MARK: - Margin Tab

    private func marginTab(snapshots: [CostingEngine.ProductSnapshot]) -> some View {
        let sorted = snapshots.sorted { ($0.profitMargin ?? Decimal(-999)) > ($1.profitMargin ?? Decimal(-999)) }
        let withMargin = sorted.filter { $0.hasPricing && $0.profitMargin != nil }
        let unpriced = sorted.filter { !$0.hasPricing }
        let maxVal = withMargin.compactMap { $0.profitMargin }.max() ?? 0

        return GroupBox {
            VStack(spacing: AppTheme.Spacing.xs) {
                CalculatorSectionHeader(title: "Profit Margin", icon: "percent")

                if withMargin.isEmpty {
                    noPricingHint
                } else {
                    ForEach(withMargin, id: \.product.persistentModelID) { snap in
                        if let margin = snap.profitMargin {
                            NavigationLink { ProductDetailView(product: snap.product) } label: {
                                portfolioBarRow(
                                    imageData: snap.product.image,
                                    title: snap.product.title,
                                    value: CostingEngine.signedProfitPrefix(margin) + PercentageFormat.toDisplay(margin) + "%",
                                    proportion: proportion(margin, max: maxVal),
                                    barColor: margin >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive,
                                    valueColor: margin >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive,
                                    subtitle: secondaryMetrics(earnings: snap.earnings, hourlyRate: snap.hourlyRate)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    unpricedRows(unpriced)
                }
            }
        }
        .backgroundStyle(AppTheme.Colors.pricingSurface)
    }

    // MARK: - Hourly Rate Tab

    private func hourlyRateTab(snapshots: [CostingEngine.ProductSnapshot]) -> some View {
        let sorted = snapshots.sorted { ($0.hourlyRate ?? Decimal(-999)) > ($1.hourlyRate ?? Decimal(-999)) }
        let withRate = sorted.filter { $0.hasPricing && $0.hourlyRate != nil }
        let noHours = sorted.filter { $0.hasPricing && $0.hourlyRate == nil }
        let unpriced = sorted.filter { !$0.hasPricing }
        let maxVal = withRate.compactMap { $0.hourlyRate }.max() ?? 0

        return GroupBox {
            VStack(spacing: AppTheme.Spacing.xs) {
                CalculatorSectionHeader(title: "Your Hourly Pay", icon: "clock")

                if withRate.isEmpty && noHours.isEmpty {
                    noPricingHint
                } else {
                    ForEach(withRate, id: \.product.persistentModelID) { snap in
                        if let rate = snap.hourlyRate {
                            NavigationLink { ProductDetailView(product: snap.product) } label: {
                                portfolioBarRow(
                                    imageData: snap.product.image,
                                    title: snap.product.title,
                                    value: formatter.format(rate) + "/hr",
                                    proportion: proportion(rate, max: maxVal),
                                    barColor: rate >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive,
                                    valueColor: rate >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive,
                                    subtitle: secondaryMetrics(earnings: snap.earnings, margin: snap.profitMargin)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Products with pricing but no labor hours
                    ForEach(noHours, id: \.product.persistentModelID) { snap in
                        NavigationLink { ProductDetailView(product: snap.product) } label: {
                            HStack(spacing: AppTheme.Spacing.md) {
                                ProductThumbnailView(imageData: snap.product.image, size: 32)
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                    Text(snap.product.title)
                                        .font(AppTheme.Typography.bodyText)
                                        .lineLimit(1)
                                    Text("No labor steps")
                                        .font(AppTheme.Typography.note)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Text("N/A")
                                    .font(AppTheme.Typography.note)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, AppTheme.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                    }

                    unpricedRows(unpriced)
                }
            }
        }
        .backgroundStyle(AppTheme.Colors.pricingSurface)
    }

    // MARK: - Cost Tab

    private func costTab(snapshots: [CostingEngine.ProductSnapshot]) -> some View {
        let sorted = snapshots.sorted { $0.productionCost > $1.productionCost }

        return GroupBox {
            VStack(spacing: AppTheme.Spacing.xs) {
                CalculatorSectionHeader(title: "Cost Breakdown", icon: "chart.bar")

                ForEach(sorted, id: \.product.persistentModelID) { snap in
                    NavigationLink { ProductDetailView(product: snap.product) } label: {
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
        let fractions = CostingEngine.costBreakdownFractions(
            laborCostBuffered: snap.laborCostBuffered,
            materialCostBuffered: snap.materialCostBuffered,
            shippingCost: snap.shippingCost
        )
        let lFrac = CGFloat(fractions.labor)
        let mFrac = CGFloat(fractions.material)
        let sFrac = CGFloat(fractions.shipping)

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
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xs))
            }
            .frame(height: AppTheme.Sizing.progressBarHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cost breakdown: Labor \(formatter.format(snap.laborCostBuffered)), Materials \(formatter.format(snap.materialCostBuffered)), Shipping \(formatter.format(snap.shippingCost))")

            // Text breakdown
            HStack(spacing: AppTheme.Spacing.sm) {
                Text("Labor \(formatter.format(snap.laborCostBuffered))")
                Text("·").foregroundStyle(.quaternary)
                Text("Materials \(formatter.format(snap.materialCostBuffered))")
                if snap.shippingCost > 0 {
                    Text("·").foregroundStyle(.quaternary)
                    Text("Ship \(formatter.format(snap.shippingCost))")
                }
            }
            .font(AppTheme.Typography.note)
            .foregroundStyle(.tertiary)
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
        .accessibilityHidden(true)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Circle().fill(color).frame(width: AppTheme.Sizing.legendDot, height: AppTheme.Sizing.legendDot)
            Text(label)
        }
    }

    // MARK: - Summary Card

    private func portfolioSummaryCard(
        avg: (avgEarnings: Decimal, avgProfitMargin: Decimal?,
              avgHourlyRate: Decimal?, pricedCount: Int, totalCount: Int),
        snapshots: [CostingEngine.ProductSnapshot]
    ) -> some View {
        let priced = snapshots.filter { $0.hasPricing }
        let top = priced.max(by: { $0.earnings < $1.earnings })
        let worst = priced.min(by: { $0.earnings < $1.earnings })

        return VStack(spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("Portfolio Overview")
                    .font(AppTheme.Typography.sectionHeader)
                Spacer()
                Picker("Platform", selection: $selectedPlatform) {
                    ForEach(PlatformType.allCases, id: \.self) { platform in
                        Text(platform.rawValue).tag(platform)
                    }
                }
                .pickerStyle(.segmented)
            }

            DetailRow(label: "Products Priced", value: "\(avg.pricedCount) of \(avg.totalCount)")

            HStack {
                Text("Avg. Earnings / Sale")
                    .font(AppTheme.Typography.bodyText)
                Spacer()
                Text(formatter.format(avg.avgEarnings))
                    .font(AppTheme.Typography.heroPrice)
                    .foregroundStyle(avg.avgEarnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive)
            }
            .accessibilityLabel("Average Earnings per Sale: \(formatter.format(avg.avgEarnings))")

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
        .padding(AppTheme.Spacing.md)
        .cardStyle()
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

    // MARK: - Shared Components

    /// Unpriced product rows shown at the bottom of Earnings, Margin, and $/Hour tabs.
    @ViewBuilder
    private func unpricedRows(_ unpriced: [CostingEngine.ProductSnapshot]) -> some View {
        ForEach(unpriced, id: \.product.persistentModelID) { snap in
            NavigationLink { ProductDetailView(product: snap.product) } label: {
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

    @ViewBuilder
    private func portfolioBarRow(
        imageData: Data?,
        title: String,
        value: String,
        proportion: CGFloat,
        barColor: Color,
        valueColor: Color,
        subtitle: String? = nil
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
                    .frame(width: max(geo.size.width * proportion, AppTheme.Sizing.barMinWidth), height: AppTheme.Sizing.barHeight)
            }
            .frame(height: AppTheme.Sizing.barHeight)

            if let subtitle {
                Text(subtitle)
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    // MARK: - Empty States

    private var noPricingHint: some View {
        ContentUnavailableView(
            "No \(selectedPlatform.rawValue) Prices Set",
            systemImage: "tag",
            description: Text("Set actual prices on the \(selectedPlatform.rawValue) tab in each product's Price section to see this ranking.")
        )
    }

    // MARK: - Helpers

    /// Builds secondary metrics string for Earnings tab (shows margin + hourly rate).
    private func secondaryMetrics(margin: Decimal?, hourlyRate: Decimal?) -> String {
        var parts: [String] = []
        if let margin { parts.append(PercentageFormat.toDisplay(margin) + "% margin") }
        if let hourlyRate { parts.append(formatter.format(hourlyRate) + "/hr") }
        return parts.joined(separator: " · ")
    }

    /// Builds secondary metrics string for Margin tab (shows earnings + hourly rate).
    private func secondaryMetrics(earnings: Decimal, hourlyRate: Decimal?) -> String {
        var parts: [String] = [formatter.format(earnings) + " earnings"]
        if let hourlyRate { parts.append(formatter.format(hourlyRate) + "/hr") }
        return parts.joined(separator: " · ")
    }

    /// Builds secondary metrics string for $/Hour tab (shows earnings + margin).
    private func secondaryMetrics(earnings: Decimal, margin: Decimal?) -> String {
        var parts: [String] = [formatter.format(earnings) + " earnings"]
        if let margin { parts.append(PercentageFormat.toDisplay(margin) + "% margin") }
        return parts.joined(separator: " · ")
    }

    private func proportion(_ value: Decimal, max: Decimal) -> CGFloat {
        guard max > 0 else { return 0 }
        let raw = CGFloat(NSDecimalNumber(decimal: value / max).doubleValue)
        return Swift.min(Swift.max(raw, 0), 1)
    }
}
