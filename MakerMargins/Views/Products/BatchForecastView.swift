// BatchForecastView.swift
// MakerMargins
//
// Batch forecasting calculator — projects total labor time, material needs,
// production cost, and revenue for a given batch size.
// Rendered within the Forecast sub-tab of ProductDetailView.
// Epic 5.

import SwiftUI

struct BatchForecastView: View {
    let product: Product

    @State private var batchSize: Int = 10
    @State private var batchSizeText: String = "10"
    @FocusState private var batchSizeFocused: Bool
    @Environment(\.currencyFormatter) private var formatter

    // MARK: - Convenience

    private var sortedStepLinks: [ProductWorkStep] {
        product.productWorkSteps.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedMaterialLinks: [ProductMaterial] {
        product.productMaterials.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var hasLaborSteps: Bool { !product.productWorkSteps.isEmpty }
    private var hasMaterials: Bool { !product.productMaterials.isEmpty }

    // MARK: - Batch Aggregates

    private var totalBatchLaborHours: Decimal {
        CostingEngine.batchLaborHours(product: product, batchSize: batchSize)
    }

    private var batchLaborCostBuffered: Decimal {
        CostingEngine.batchLaborCostBuffered(product: product, batchSize: batchSize)
    }

    private var batchMaterialCostBuffered: Decimal {
        CostingEngine.batchMaterialCostBuffered(product: product, batchSize: batchSize)
    }

    private var batchShippingCost: Decimal {
        CostingEngine.batchShippingCost(product: product, batchSize: batchSize)
    }

    // MARK: - Revenue

    /// Selects the best pricing for revenue forecasting.
    /// Prefers General for broad applicability (no platform-specific locked fees).
    /// Falls back to any pricing with an actual price if General has none.
    private var activePricing: ProductPricing? {
        let withPrice = product.productPricings.filter { $0.actualPrice > 0 }
        if let general = withPrice.first(where: { $0.platformType == .general }) {
            return general
        }
        return withPrice.first
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            batchSizeSection

            if hasLaborSteps {
                laborTimeForecastSection
            }

            if hasMaterials {
                materialShoppingListSection
            }

            if hasLaborSteps || hasMaterials {
                if activePricing != nil {
                    revenueForecastSection
                } else {
                    pricingHint
                }
            } else {
                emptyProductHint
            }
        }
        .padding(.horizontal)
        .onChange(of: batchSizeText) { _, newValue in
            if let parsed = Int(newValue), parsed >= 1 {
                batchSize = parsed
            }
        }
        .onChange(of: batchSize) { _, newValue in
            let clamped = max(1, newValue)
            if clamped != newValue { batchSize = clamped }
            let text = "\(clamped)"
            if batchSizeText != text { batchSizeText = text }
        }
        .onChange(of: batchSizeFocused) { _, focused in
            if focused {
                if batchSizeText == "10" || batchSizeText == "1" { batchSizeText = "" }
            } else {
                if batchSizeText.trimmingCharacters(in: .whitespaces).isEmpty {
                    batchSize = 10
                    batchSizeText = "10"
                } else if let parsed = Int(batchSizeText) {
                    batchSize = max(1, parsed)
                    batchSizeText = "\(batchSize)"
                }
            }
        }
    }

    // MARK: - Section 1: Batch Size Input

    private var batchSizeSection: some View {
        GroupBox {
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("How many are you making?")
                    .font(AppTheme.Typography.sectionHeader)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        batchSize = max(1, batchSize - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                    .disabled(batchSize <= 1)
                    .frame(minWidth: 44, minHeight: 44)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Decrease batch size")

                    TextField("", text: $batchSizeText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(AppTheme.Typography.heroPrice)
                        .frame(width: AppTheme.Sizing.inputMedium)
                        .editableFieldStyle()
                        .focused($batchSizeFocused)

                    Button {
                        batchSize += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Increase batch size")
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach([5, 10, 25, 50, 100], id: \.self) { size in
                        Button("\(size)") {
                            batchSize = size
                            batchSizeText = "\(size)"
                        }
                        .buttonStyle(.bordered)
                        .tint(batchSize == size ? AppTheme.Colors.accent : .secondary)
                        .accessibilityLabel("Set batch size to \(size)")
                    }
                }
            }
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .backgroundStyle(AppTheme.Colors.pricingSurface)
    }

    // MARK: - Section 2: Labor Time Forecast

    private var laborTimeForecastSection: some View {
        GroupBox {
            VStack(spacing: AppTheme.Spacing.xs) {
                CalculatorSectionHeader(title: "Labor Time", icon: "clock")

                VStack(spacing: 0) {
                    ForEach(Array(sortedStepLinks.enumerated()), id: \.element.persistentModelID) { index, link in
                        let perProduct = CostingEngine.laborHoursPerProduct(link: link)
                        let batchHours = CostingEngine.batchStepHours(link: link, batchSize: batchSize)

                        HStack {
                            Text(link.workStep?.title ?? "—")
                                .font(AppTheme.Typography.bodyText)
                            Spacer()
                            VStack(alignment: .trailing, spacing: AppTheme.Spacing.xxxs) {
                                Text(CostingEngine.formatPerUnitTime(hours: perProduct))
                                    .font(AppTheme.Typography.note)
                                    .foregroundStyle(.secondary)
                                Text("\(CostingEngine.formatHours(batchHours)) hrs")
                                    .font(AppTheme.Typography.bodyText)
                                    .foregroundStyle(AppTheme.Colors.accent)
                            }
                        }
                        .padding(.vertical, AppTheme.Spacing.sm)

                        if index < sortedStepLinks.count - 1 {
                            Divider()
                        }
                    }
                }
                .sectionGroupStyle()

                VStack(spacing: AppTheme.Spacing.xs) {
                    HStack {
                        Text("Total Labor")
                            .font(AppTheme.Typography.sectionHeader)
                        Spacer()
                        Text("\(CostingEngine.formatHours(totalBatchLaborHours)) hrs")
                            .font(AppTheme.Typography.sectionHeader)
                    }
                    Text(CostingEngine.formatHoursReadable(totalBatchLaborHours))
                        .font(AppTheme.Typography.heroPrice)
                        .foregroundStyle(AppTheme.Colors.accent)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .accessibilityLabel("Total Labor Time: \(CostingEngine.formatHoursReadable(totalBatchLaborHours))")
                .heroCardStyle()
            }
        }
        .backgroundStyle(AppTheme.Colors.pricingSurface)
    }

    // MARK: - Section 3: Material Shopping List

    private var materialShoppingListSection: some View {
        GroupBox {
            VStack(spacing: AppTheme.Spacing.xs) {
                CalculatorSectionHeader(title: "Shopping List", icon: "cart")

                ForEach(sortedMaterialLinks, id: \.persistentModelID) { link in
                    materialRow(link: link)
                }

                materialSummaryHero
            }
        }
        .backgroundStyle(AppTheme.Colors.pricingSurface)
    }

    private func materialRow(link: ProductMaterial) -> some View {
        let material = link.material
        let unitName = material?.unitName ?? "unit"
        let unitsNeeded = CostingEngine.batchMaterialUnits(link: link, batchSize: batchSize)
        let bulkQty = material?.bulkQuantity ?? 1
        let bulkCost = material?.bulkCost ?? 0
        let purchaseInfo = CostingEngine.bulkPurchasesNeeded(unitsNeeded: unitsNeeded, bulkQuantity: bulkQty)
        let purchaseCost = CostingEngine.batchPurchaseCost(purchases: purchaseInfo.purchases, bulkCost: bulkCost)

        return VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                Text(material?.title ?? "—")
                    .font(AppTheme.Typography.bodyText)
                Spacer()
                Text("\(CostingEngine.formatUnits(unitsNeeded)) \(unitName)")
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(AppTheme.Colors.accent)
            }

            HStack {
                Text("Buy \(purchaseInfo.purchases) \u{00d7} \(CostingEngine.formatUnits(bulkQty)) \(unitName)")
                    .font(AppTheme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatter.format(purchaseCost))
                    .font(AppTheme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
            }

            if purchaseInfo.leftover > 0 {
                Text("\(CostingEngine.formatUnits(purchaseInfo.leftover)) \(unitName) leftover")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
        }
        .sectionGroupStyle()
    }

    private var materialSummaryHero: some View {
        let totalPurchaseCost = sortedMaterialLinks.reduce(Decimal.zero) { sum, link in
            let material = link.material
            let unitsNeeded = CostingEngine.batchMaterialUnits(link: link, batchSize: batchSize)
            let bulkQty = material?.bulkQuantity ?? 1
            let bulkCost = material?.bulkCost ?? 0
            let purchaseInfo = CostingEngine.bulkPurchasesNeeded(unitsNeeded: unitsNeeded, bulkQuantity: bulkQty)
            return sum + CostingEngine.batchPurchaseCost(purchases: purchaseInfo.purchases, bulkCost: bulkCost)
        }

        let materialLabel = product.materialBuffer > 0
            ? "Batch Material Cost (+\(PercentageFormat.toDisplay(product.materialBuffer))%)"
            : "Batch Material Cost"

        return VStack(spacing: AppTheme.Spacing.xs) {
            DetailRow(
                label: materialLabel,
                value: formatter.format(batchMaterialCostBuffered)
            )
            DetailRow(
                label: "Total to Spend",
                value: formatter.format(totalPurchaseCost)
            )

            if totalPurchaseCost > batchMaterialCostBuffered {
                Text("Includes surplus from buying full bulk packages.")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
        }
        .heroCardStyle()
    }

    // MARK: - Section 4: Revenue Forecast

    @ViewBuilder
    private var revenueForecastSection: some View {
        if let pricing = activePricing {
            let f = CostingEngine.resolvedFees(
                platformType: pricing.platformType,
                userPlatformFee: pricing.platformFee,
                userPaymentProcessingFee: pricing.paymentProcessingFee,
                userMarketingFee: pricing.marketingFee,
                userPercentSalesFromMarketing: pricing.percentSalesFromMarketing,
                userProfitMargin: pricing.profitMargin
            )

            let revenue = CostingEngine.batchRevenue(
                actualPrice: pricing.actualPrice,
                actualShippingCharge: pricing.actualShippingCharge,
                batchSize: batchSize
            )

            let fees = CostingEngine.batchTotalFees(
                actualPrice: pricing.actualPrice,
                actualShippingCharge: pricing.actualShippingCharge,
                platformFee: f.platformFee,
                paymentProcessingFee: f.paymentProcessingFee,
                paymentProcessingFixed: f.paymentProcessingFixed,
                marketingFee: f.marketingFee,
                percentSalesFromMarketing: f.percentSalesFromMarketing,
                batchSize: batchSize
            )

            let batchProductionExShipping = CostingEngine.batchProductionCostExShipping(product: product, batchSize: batchSize)

            let profit = CostingEngine.batchProfit(
                actualPrice: pricing.actualPrice,
                actualShippingCharge: pricing.actualShippingCharge,
                productionCostExShipping: CostingEngine.productionCostExShipping(product: product),
                shippingCost: product.shippingCost,
                platformFee: f.platformFee,
                paymentProcessingFee: f.paymentProcessingFee,
                paymentProcessingFixed: f.paymentProcessingFixed,
                marketingFee: f.marketingFee,
                percentSalesFromMarketing: f.percentSalesFromMarketing,
                batchSize: batchSize
            )

            GroupBox {
                VStack(spacing: AppTheme.Spacing.xs) {
                    CalculatorSectionHeader(title: "Revenue Forecast", icon: "chart.bar")

                    VStack(spacing: 0) {
                        DetailRow(label: "Revenue", value: formatter.format(revenue))
                        if fees > 0 {
                            DetailRow(label: "Total Fees", value: "-\(formatter.format(fees))")
                                .foregroundStyle(.secondary)
                        }
                        if batchProductionExShipping > 0 {
                            DetailRow(label: "Production Cost", value: "-\(formatter.format(batchProductionExShipping))")
                                .foregroundStyle(.secondary)
                        }
                        if batchShippingCost > 0 {
                            DetailRow(label: "Shipping", value: "-\(formatter.format(batchShippingCost))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .sectionGroupStyle()

                    VStack(spacing: AppTheme.Spacing.sm) {
                        let batchEarnings = CostingEngine.batchEarnings(batchProfit: profit, batchLaborCostBuffered: batchLaborCostBuffered)
                        let grossRevenue = CostingEngine.batchRevenue(
                            actualPrice: pricing.actualPrice,
                            actualShippingCharge: pricing.actualShippingCharge,
                            batchSize: batchSize
                        )

                        // Batch Earnings — single hero metric
                        HStack {
                            Text("Batch Earnings")
                                .font(AppTheme.Typography.sectionHeader)
                            Spacer()
                            Text(CostingEngine.signedProfitPrefix(batchEarnings) + formatter.format(batchEarnings))
                                .font(AppTheme.Typography.heroPrice)
                                .foregroundStyle(batchEarnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive)
                        }

                        if batchSize > 0 {
                            HStack {
                                Text("Earnings / Unit")
                                    .font(AppTheme.Typography.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatter.format(CostingEngine.batchEarningsPerUnit(batchEarnings: batchEarnings, batchSize: batchSize) ?? 0))
                                    .font(AppTheme.Typography.sectionHeader)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Per-unit profit (used for margin and hourly pay)
                        let perUnitProfit = CostingEngine.actualProfit(
                            product: product,
                            actualPrice: pricing.actualPrice,
                            actualShippingCharge: pricing.actualShippingCharge,
                            platformFee: f.platformFee,
                            paymentProcessingFee: f.paymentProcessingFee,
                            paymentProcessingFixed: f.paymentProcessingFixed,
                            marketingFee: f.marketingFee,
                            percentSalesFromMarketing: f.percentSalesFromMarketing
                        )

                        // Profit Margin — uses per-unit profit / per-unit revenue (independent of batch size)
                        if grossRevenue > 0 {
                            let margin = CostingEngine.actualProfitMargin(
                                profit: perUnitProfit,
                                actualPrice: pricing.actualPrice,
                                actualShippingCharge: pricing.actualShippingCharge
                            ) ?? 0
                            HStack {
                                Text("Profit Margin")
                                    .font(AppTheme.Typography.bodyText)
                                Spacer()
                                Text(CostingEngine.signedProfitPrefix(margin) + "\(PercentageFormat.toDisplay(margin))%")
                                    .font(AppTheme.Typography.sectionHeader)
                                    .foregroundStyle(batchEarnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive)
                            }
                        }

                        // Effective Hourly Rate — only when labor hours exist
                        if totalBatchLaborHours > 0 {
                            if let perHour = CostingEngine.takeHomePerHour(
                                product: product,
                                actualProfit: perUnitProfit
                            ) {
                                HStack {
                                    Text("Your Hourly Pay")
                                        .font(AppTheme.Typography.bodyText)
                                    Spacer()
                                    Text(CostingEngine.signedProfitPrefix(perHour) + "\(formatter.format(perHour)) / hr")
                                        .font(AppTheme.Typography.sectionHeader)
                                        .foregroundStyle(batchEarnings >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive)
                                }
                            }
                        }

                        Text("Based on \(pricing.platformType.rawValue) pricing")
                            .font(AppTheme.Typography.rowCaption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityLabel("Batch Earnings: \(formatter.format(profit + batchLaborCostBuffered))")
                    .heroCardStyle()
                }
            }
            .backgroundStyle(AppTheme.Colors.pricingSurface)
        }
    }

    // MARK: - Hints

    private var pricingHint: some View {
        Text("Set actual prices in the Price tab to see revenue projections.")
            .font(AppTheme.Typography.note)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var emptyProductHint: some View {
        ContentUnavailableView(
            "Nothing to Forecast",
            systemImage: "chart.bar.xaxis.ascending",
            description: Text("Add labor steps and materials in the Build tab to forecast batch production.")
        )
    }

    // MARK: - Helpers
}
