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
        CostingEngine.totalLaborCostBuffered(product: product) * Decimal(batchSize)
    }

    private var batchMaterialCostBuffered: Decimal {
        CostingEngine.totalMaterialCostBuffered(product: product) * Decimal(batchSize)
    }

    private var batchShippingCost: Decimal {
        product.shippingCost * Decimal(batchSize)
    }

    private var totalBatchCost: Decimal {
        CostingEngine.batchProductionCost(product: product, batchSize: batchSize)
    }

    private var costPerUnit: Decimal {
        CostingEngine.batchCostPerUnit(batchProductionCost: totalBatchCost, batchSize: batchSize)
    }

    // MARK: - Revenue

    private var activePricing: ProductPricing? {
        product.productPricings.first { $0.actualPrice > 0 }
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
                batchCostSummarySection

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
                    .buttonStyle(.plain)

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
                    .buttonStyle(.plain)
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

                ForEach(sortedStepLinks, id: \.persistentModelID) { link in
                    let perProduct = CostingEngine.laborHoursPerProduct(link: link)
                    let batchHours = CostingEngine.batchStepHours(link: link, batchSize: batchSize)

                    HStack {
                        Text(link.workStep?.title ?? "—")
                            .font(AppTheme.Typography.bodyText)
                        Spacer()
                        VStack(alignment: .trailing, spacing: AppTheme.Spacing.xxxs) {
                            Text("\(CostingEngine.formatHours(perProduct)) hrs/ea")
                                .font(AppTheme.Typography.note)
                                .foregroundStyle(.secondary)
                            Text("\(CostingEngine.formatHours(batchHours)) hrs")
                                .font(AppTheme.Typography.bodyText)
                                .foregroundStyle(AppTheme.Colors.accent)
                        }
                    }
                    .sectionGroupStyle()
                }

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
                Text("\(formatUnits(unitsNeeded)) \(unitName)")
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(AppTheme.Colors.accent)
            }

            HStack {
                Text("Buy \(purchaseInfo.purchases) \u{00d7} \(formatUnits(bulkQty)) \(unitName)")
                    .font(AppTheme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatter.format(purchaseCost))
                    .font(AppTheme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
            }

            if purchaseInfo.leftover > 0 {
                Text("\(formatUnits(purchaseInfo.leftover)) \(unitName) leftover")
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

    // MARK: - Section 4: Batch Cost Summary

    private var batchCostSummarySection: some View {
        GroupBox {
            VStack(spacing: AppTheme.Spacing.xs) {
                CalculatorSectionHeader(title: "Batch Cost", icon: "dollarsign.circle")

                VStack(spacing: 0) {
                    costDetailRow(
                        label: "Labor",
                        value: batchLaborCostBuffered,
                        buffer: product.laborBuffer
                    )
                    costDetailRow(
                        label: "Materials",
                        value: batchMaterialCostBuffered,
                        buffer: product.materialBuffer
                    )
                    HStack {
                        Text("Shipping")
                            .font(AppTheme.Typography.bodyText)
                        Spacer()
                        Text(formatter.format(batchShippingCost))
                            .font(AppTheme.Typography.sectionHeader)
                    }
                    .padding(.vertical, AppTheme.Spacing.sm)
                }
                .sectionGroupStyle()

                VStack(spacing: AppTheme.Spacing.sm) {
                    HStack {
                        Text("Total Batch Cost")
                            .font(AppTheme.Typography.sectionHeader)
                        Spacer()
                        Text(formatter.format(totalBatchCost))
                            .font(AppTheme.Typography.heroPrice)
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                    HStack {
                        Text("Cost Per Unit")
                            .font(AppTheme.Typography.bodyText)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatter.format(costPerUnit))
                            .font(AppTheme.Typography.sectionHeader)
                            .foregroundStyle(.secondary)
                    }
                }
                .heroCardStyle()
            }
        }
        .backgroundStyle(AppTheme.Colors.pricingSurface)
    }

    @ViewBuilder
    private func costDetailRow(label: String, value: Decimal, buffer: Decimal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxxs) {
                Text(label)
                    .font(AppTheme.Typography.bodyText)
                if buffer > 0 {
                    Text("+\(PercentageFormat.toDisplay(buffer))% buffer")
                        .font(AppTheme.Typography.note)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(formatter.format(value))
                .font(AppTheme.Typography.sectionHeader)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    // MARK: - Section 5: Revenue Forecast

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

            let batchProductionExShipping = CostingEngine.productionCostExShipping(product: product) * Decimal(batchSize)

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
                        DetailRow(label: "Total Fees", value: "-\(formatter.format(fees))")
                            .foregroundStyle(.secondary)
                        DetailRow(label: "Production Cost", value: "-\(formatter.format(batchProductionExShipping))")
                            .foregroundStyle(.secondary)
                        if batchShippingCost > 0 {
                            DetailRow(label: "Shipping", value: "-\(formatter.format(batchShippingCost))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .sectionGroupStyle()

                    VStack(spacing: AppTheme.Spacing.sm) {
                        HStack {
                            Text("Batch Profit")
                                .font(AppTheme.Typography.sectionHeader)
                            Spacer()
                            Text(formatter.format(profit))
                                .font(AppTheme.Typography.heroPrice)
                                .foregroundStyle(profit >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive)
                        }

                        if batchSize > 0 {
                            HStack {
                                Text("Profit / Unit")
                                    .font(AppTheme.Typography.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatter.format(profit / Decimal(batchSize)))
                                    .font(AppTheme.Typography.sectionHeader)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("Based on \(pricing.platformType.rawValue) pricing")
                            .font(AppTheme.Typography.rowCaption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if batchLaborCostBuffered > 0 {
                            Divider()
                            HStack {
                                Text("Batch Take-Home")
                                    .font(AppTheme.Typography.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatter.format(profit + batchLaborCostBuffered))
                                    .font(AppTheme.Typography.sectionHeader)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if totalBatchLaborHours > 0 {
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
                            if let perHour = CostingEngine.takeHomePerHour(
                                product: product,
                                actualProfit: perUnitProfit
                            ) {
                                HStack {
                                    Text("Take-Home / Hr")
                                        .font(AppTheme.Typography.bodyText)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(formatter.format(perHour))
                                        .font(AppTheme.Typography.sectionHeader)
                                        .foregroundStyle(profit >= 0 ? AppTheme.Colors.accent : AppTheme.Colors.destructive)
                                }
                            }
                        }
                    }
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

    /// Cached formatter for unit quantities — avoids allocating per call.
    private static let unitsFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 4
        f.numberStyle = .decimal
        return f
    }()

    /// Formats a Decimal quantity, stripping unnecessary trailing zeros.
    private func formatUnits(_ value: Decimal) -> String {
        Self.unitsFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}
