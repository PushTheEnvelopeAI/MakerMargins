// PricingCalculatorView.swift
// MakerMargins
//
// Inline pricing calculator and profit analysis rendered within ProductDetailView.
// Tabbed by platform (General, Etsy, Shopify, Amazon).
//
// Target Price Calculator: auto-pulls product costs, shows locked platform fees,
// lets the user adjust editable pricing settings. Target retail price updates live.
//
// Profit Analysis: user enters actual selling price and shipping charge per platform.
// Shows fee breakdown, profit per sale, profit margin, and contextual callouts
// for labor-as-income and absorbed shipping costs.
//
// Per-product pricing overrides are stored in ProductPricing, created lazily
// from PlatformFeeProfile defaults on first access.

import SwiftUI
import SwiftData

struct PricingCalculatorView: View {
    let product: Product

    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyFormatter) private var formatter

    // MARK: - State

    @State private var selectedPlatform: PlatformType = .general
    @State private var currentPricing: ProductPricing?

    @State private var platformFeeText: String = ""
    @State private var paymentProcessingFeeText: String = ""
    @State private var marketingFeeText: String = ""
    @State private var percentSalesFromMarketingText: String = ""
    @State private var profitMarginText: String = ""
    @State private var actualPriceText: String = ""
    @State private var actualShippingChargeText: String = ""

    private enum FocusableField: Hashable {
        case platformFee, paymentProcessingFee, marketingFee, percentSalesFromMarketing, profitMargin
        case actualPrice, actualShippingCharge
    }
    @FocusState private var focusedField: FocusableField?

    // MARK: - Computed

    private var productionCost: Decimal {
        CostingEngine.totalProductionCost(product: product)
    }

    private var resolved: (platformFee: Decimal, paymentProcessingFee: Decimal,
                           paymentProcessingFixed: Decimal, marketingFee: Decimal,
                           percentSalesFromMarketing: Decimal, profitMargin: Decimal) {
        guard let pricing = currentPricing else {
            return (0, 0, 0, 0, 0, Decimal(string: "0.30")!)
        }
        return CostingEngine.resolvedFees(
            platformType: selectedPlatform,
            userPlatformFee: pricing.platformFee,
            userPaymentProcessingFee: pricing.paymentProcessingFee,
            userMarketingFee: pricing.marketingFee,
            userPercentSalesFromMarketing: pricing.percentSalesFromMarketing,
            userProfitMargin: pricing.profitMargin
        )
    }

    private var computedTargetPrice: Decimal? {
        let f = resolved
        return CostingEngine.targetRetailPrice(
            product: product,
            platformFee: f.platformFee,
            paymentProcessingFee: f.paymentProcessingFee,
            paymentProcessingFixed: f.paymentProcessingFixed,
            marketingFee: f.marketingFee,
            percentSalesFromMarketing: f.percentSalesFromMarketing,
            profitMargin: f.profitMargin
        )
    }

    // MARK: - Profit Analysis Computed

    /// Whether the user has entered a selling price for the current platform.
    private var hasActualPrice: Bool {
        guard let pricing = currentPricing else { return false }
        return pricing.actualPrice > 0
    }

    /// Gross revenue = selling price + shipping charge.
    private var grossRevenue: Decimal {
        guard let pricing = currentPricing else { return 0 }
        return pricing.actualPrice + pricing.actualShippingCharge
    }

    /// Actual profit using the model-based CostingEngine overload.
    private var computedActualProfit: Decimal {
        guard let pricing = currentPricing else { return 0 }
        let f = resolved
        return CostingEngine.actualProfit(
            product: product,
            actualPrice: pricing.actualPrice,
            actualShippingCharge: pricing.actualShippingCharge,
            platformFee: f.platformFee,
            paymentProcessingFee: f.paymentProcessingFee,
            paymentProcessingFixed: f.paymentProcessingFixed,
            marketingFee: f.marketingFee,
            percentSalesFromMarketing: f.percentSalesFromMarketing
        )
    }

    /// Actual profit margin as a fraction, or nil if no revenue.
    private var computedActualProfitMargin: Decimal? {
        guard let pricing = currentPricing else { return nil }
        return CostingEngine.actualProfitMargin(
            profit: computedActualProfit,
            actualPrice: pricing.actualPrice,
            actualShippingCharge: pricing.actualShippingCharge
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            GroupBox("Target Price Calculator") {
                VStack(spacing: 0) {
                    platformPicker
                    Divider()
                    productionCostSection
                    Divider()
                    shippingCostRow
                    Divider()
                    marketingAndFeesSection
                    Divider()
                    profitMarginRow
                    Divider()
                    targetPriceRow
                }
            }
            .backgroundStyle(AppTheme.Colors.pricingSurface)

            Text("Select a platform to see your target price based on production costs, fees, and profit margin. Switch tabs to compare across platforms.")
                .font(AppTheme.Typography.note)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, AppTheme.Spacing.xs)

            profitAnalysisGroupBox

            Text("Enter your actual selling price and shipping charge to see your real profit per sale on this platform.")
                .font(AppTheme.Typography.note)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, AppTheme.Spacing.xs)
        }
        .padding(.horizontal)
        .onAppear { loadPricing() }
        .onChange(of: selectedPlatform) { _, _ in
            loadPricing()
        }
        .onChange(of: focusedField) { _, newField in
            handleFocusChange(newField)
        }
    }

    // MARK: - Sections

    private var platformPicker: some View {
        Picker("Platform", selection: $selectedPlatform) {
            ForEach(PlatformType.allCases, id: \.self) { platform in
                Text(platform.rawValue).tag(platform)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    // MARK: Production Cost

    private var productionCostSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Production Cost")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.top, AppTheme.Spacing.sm)

            if productionCost == 0 {
                emptyCostHint
            } else {
                DetailRow(
                    label: "Material Cost",
                    value: formatter.format(CostingEngine.totalMaterialCostBuffered(product: product))
                )
                Divider()
                DetailRow(
                    label: "Labor Cost",
                    value: formatter.format(CostingEngine.totalLaborCostBuffered(product: product))
                )
            }
        }
    }

    private var emptyCostHint: some View {
        HStack {
            Spacer()
            VStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Add materials or labor costs to calculate pricing.")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, AppTheme.Spacing.lg)
            Spacer()
        }
    }

    // MARK: Shipping Cost

    private var shippingCostRow: some View {
        DetailRow(
            label: "Shipping Cost",
            value: formatter.format(product.shippingCost)
        )
    }

    // MARK: Marketing and Fees

    private var marketingAndFeesSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Marketing and Fees")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.top, AppTheme.Spacing.sm)

            // Platform Fee
            feeRow(
                label: "Platform Fee",
                lockedDisplay: selectedPlatform.platformFeeDisplay,
                text: $platformFeeText,
                field: .platformFee,
                writeBack: { currentPricing?.platformFee = $0 }
            )

            // Payment Processing
            feeRow(
                label: "Payment Processing",
                lockedDisplay: selectedPlatform.paymentProcessingDisplay,
                text: $paymentProcessingFeeText,
                field: .paymentProcessingFee,
                writeBack: { currentPricing?.paymentProcessingFee = $0 }
            )

            // Marketing Fees
            feeRow(
                label: "Marketing Fees",
                lockedDisplay: selectedPlatform.marketingFeeDisplay,
                text: $marketingFeeText,
                field: .marketingFee,
                writeBack: { currentPricing?.marketingFee = $0 }
            )

            // % Sales from Ads — always editable
            PercentageInputField(
                label: "% Sales from Ads",
                text: $percentSalesFromMarketingText,
                field: FocusableField.percentSalesFromMarketing,
                focusBinding: $focusedField,
                writeBack: { currentPricing?.percentSalesFromMarketing = $0 }
            )
            .padding(.vertical, AppTheme.Spacing.xs)
        }
    }

    /// Renders a fee row as either a locked display string or an editable PercentageInputField.
    @ViewBuilder
    private func feeRow(
        label: String,
        lockedDisplay: String?,
        text: Binding<String>,
        field: FocusableField,
        writeBack: @escaping (Decimal) -> Void
    ) -> some View {
        if let display = lockedDisplay {
            HStack {
                Text(label)
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(display)
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, AppTheme.Spacing.xs)
        } else {
            PercentageInputField(
                label: label,
                text: text,
                field: field,
                focusBinding: $focusedField,
                writeBack: writeBack
            )
            .padding(.vertical, AppTheme.Spacing.xs)
        }
    }

    // MARK: Profit Margin

    private var profitMarginRow: some View {
        PercentageInputField(
            label: "Profit Margin",
            text: $profitMarginText,
            field: FocusableField.profitMargin,
            focusBinding: $focusedField,
            writeBack: { currentPricing?.profitMargin = $0 }
        )
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    // MARK: Target Price

    private var targetPriceRow: some View {
        HStack {
            Text("Target Price")
                .font(AppTheme.Typography.sectionHeader)
            Spacer()
            if let price = computedTargetPrice {
                Text(formatter.format(price))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.accent)
            } else {
                Text("— (fees too high)")
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
    }

    // MARK: - Profit Analysis

    private var profitAnalysisGroupBox: some View {
        GroupBox("Profit Analysis") {
            VStack(spacing: 0) {
                actualPricingSection

                if hasActualPrice {
                    Divider()
                    profitBreakdownSection
                    Divider()
                    profitHeroSection
                } else if computedTargetPrice != nil {
                    Divider()
                    useTargetPriceButton
                }
            }
        }
        .backgroundStyle(AppTheme.Colors.pricingSurface)
        .onChange(of: actualPriceText) { _, newValue in
            let value = Decimal(string: newValue) ?? 0
            currentPricing?.actualPrice = value >= 0 ? value : 0
        }
        .onChange(of: actualShippingChargeText) { _, newValue in
            let value = Decimal(string: newValue) ?? 0
            currentPricing?.actualShippingCharge = value >= 0 ? value : 0
        }
    }

    private var actualPricingSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your Actual Pricing")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.top, AppTheme.Spacing.sm)

            HStack {
                Text("Selling Price")
                    .font(AppTheme.Typography.bodyText)
                Spacer()
                CurrencyInputField(
                    symbol: formatter.symbol,
                    text: $actualPriceText
                )
                .editableFieldStyle()
            }
            .padding(.vertical, AppTheme.Spacing.xs)

            Divider()

            HStack {
                Text("Shipping Charge")
                    .font(AppTheme.Typography.bodyText)
                Spacer()
                CurrencyInputField(
                    symbol: formatter.symbol,
                    text: $actualShippingChargeText
                )
                .editableFieldStyle()
            }
            .padding(.vertical, AppTheme.Spacing.xs)
        }
    }

    private var useTargetPriceButton: some View {
        HStack {
            Spacer()
            Button {
                if var target = computedTargetPrice {
                    var rounded = Decimal()
                    NSDecimalRound(&rounded, &target, 2, .plain)
                    let display = "\(rounded)"
                    actualPriceText = display
                    currentPricing?.actualPrice = rounded
                }
            } label: {
                Label(
                    "Use Target Price (\(formatter.format(computedTargetPrice ?? 0)))",
                    systemImage: "arrow.up.left"
                )
                .font(AppTheme.Typography.bodyText)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.Colors.accent)
            Spacer()
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var profitBreakdownSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Breakdown")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.top, AppTheme.Spacing.sm)

            DetailRow(
                label: "Revenue",
                value: formatter.format(grossRevenue)
            )

            let f = resolved

            // Platform Fees
            let platformFeeAmount = grossRevenue * f.platformFee
            if platformFeeAmount > 0 {
                Divider()
                DetailRow(
                    label: "Platform Fees",
                    value: "-\(formatter.format(platformFeeAmount))"
                )
            }

            // Processing Fees (includes fixed fee)
            let processingAmount = grossRevenue * f.paymentProcessingFee + f.paymentProcessingFixed
            if processingAmount > 0 {
                Divider()
                DetailRow(
                    label: "Processing Fees",
                    value: "-\(formatter.format(processingAmount))"
                )
            }

            // Marketing Fees (hidden when effective rate is zero)
            let effectiveMarketing = CostingEngine.effectiveMarketingRate(
                marketingFee: f.marketingFee,
                percentSalesFromMarketing: f.percentSalesFromMarketing
            )
            let marketingAmount = (currentPricing?.actualPrice ?? 0) * effectiveMarketing
            if marketingAmount > 0 {
                Divider()
                DetailRow(
                    label: "Marketing Fees",
                    value: "-\(formatter.format(marketingAmount))"
                )
            }

            // Production Cost (labor + material buffered, no shipping)
            let prodCost = CostingEngine.productionCostExShipping(product: product)
            Divider()
            DetailRow(
                label: "Production Cost",
                value: "-\(formatter.format(prodCost))"
            )

            // Your Shipping Cost (maker's actual cost)
            if product.shippingCost > 0 {
                Divider()
                DetailRow(
                    label: "Your Shipping Cost",
                    value: "-\(formatter.format(product.shippingCost))"
                )
            }

            // Zero production cost warning
            if prodCost == 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Production cost is $0 — add materials or labor for accurate profit.")
                        .font(AppTheme.Typography.note)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, AppTheme.Spacing.sm)
            }
        }
    }

    private var profitHeroSection: some View {
        VStack(spacing: 0) {
            // Profit per Sale
            HStack {
                Text("Profit per Sale")
                    .font(AppTheme.Typography.sectionHeader)
                Spacer()
                Text(formatter.format(computedActualProfit))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(computedActualProfit >= 0 ? AppTheme.Colors.accent : .red)
            }
            .padding(.vertical, AppTheme.Spacing.md)

            // Profit Margin
            if let margin = computedActualProfitMargin {
                Divider()
                HStack {
                    Text("Profit Margin")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    Text("\(PercentageFormat.toDisplay(margin))%")
                        .font(AppTheme.Typography.sectionHeader)
                        .foregroundStyle(computedActualProfit >= 0 ? AppTheme.Colors.accent : .red)
                }
                .padding(.vertical, AppTheme.Spacing.sm)
            }

            // Labor callout
            let laborCost = CostingEngine.totalLaborCostBuffered(product: product)
            if laborCost > 0 {
                Divider()
                laborCallout(laborCost: laborCost)
            }

            // Shipping absorbed callout
            if let pricing = currentPricing,
               pricing.actualShippingCharge == 0,
               product.shippingCost > 0 {
                Divider()
                shippingAbsorbedCallout
            }
        }
    }

    private func laborCallout(laborCost: Decimal) -> some View {
        let takeHome = computedActualProfit + laborCost
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Your labor (\(formatter.format(laborCost))) is also your income. Total take-home per sale: \(formatter.format(takeHome))")
                .font(AppTheme.Typography.note)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var shippingAbsorbedCallout: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("You're absorbing \(formatter.format(product.shippingCost)) in shipping costs on this platform.")
                .font(AppTheme.Typography.note)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    // MARK: - Data Loading

    /// Finds or lazily creates the ProductPricing for the current product and selected platform.
    private func loadPricing() {
        if let existing = product.productPricings.first(where: { $0.platformType == selectedPlatform }) {
            currentPricing = existing
        } else {
            let defaults = fetchDefaults()
            let pricing = ProductPricing(
                product: product,
                platformType: selectedPlatform,
                platformFee: defaults.platformFee,
                paymentProcessingFee: defaults.paymentProcessingFee,
                marketingFee: defaults.marketingFee,
                percentSalesFromMarketing: defaults.percentSalesFromMarketing,
                profitMargin: defaults.profitMargin
            )
            modelContext.insert(pricing)
            currentPricing = pricing
        }
        loadFieldTexts()
    }

    /// Fetches the single PlatformFeeProfile defaults record, or returns system defaults.
    private func fetchDefaults() -> PlatformFeeProfile {
        let allProfiles = (try? modelContext.fetch(FetchDescriptor<PlatformFeeProfile>())) ?? []
        return allProfiles.first ?? PlatformFeeProfile()
    }

    /// Populates text fields from the current pricing record.
    private func loadFieldTexts() {
        guard let pricing = currentPricing else { return }
        platformFeeText = PercentageFormat.toDisplay(pricing.platformFee)
        paymentProcessingFeeText = PercentageFormat.toDisplay(pricing.paymentProcessingFee)
        marketingFeeText = PercentageFormat.toDisplay(pricing.marketingFee)
        percentSalesFromMarketingText = PercentageFormat.toDisplay(pricing.percentSalesFromMarketing)
        profitMarginText = PercentageFormat.toDisplay(pricing.profitMargin)
        actualPriceText = "\(pricing.actualPrice)"
        actualShippingChargeText = "\(pricing.actualShippingCharge)"
    }

    // MARK: - Focus Handling

    private func handleFocusChange(_ newField: FocusableField?) {
        let fields: [(text: Binding<String>, defaultValue: String, field: FocusableField)] = [
            ($platformFeeText, "0", .platformFee),
            ($paymentProcessingFeeText, "0", .paymentProcessingFee),
            ($marketingFeeText, "0", .marketingFee),
            ($percentSalesFromMarketingText, "0", .percentSalesFromMarketing),
            ($profitMarginText, "0", .profitMargin),
            ($actualPriceText, "0", .actualPrice),
            ($actualShippingChargeText, "0", .actualShippingCharge),
        ]

        for f in fields {
            if newField == f.field {
                if f.text.wrappedValue == f.defaultValue { f.text.wrappedValue = "" }
            } else {
                if f.text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    f.text.wrappedValue = f.defaultValue
                }
            }
        }
    }
}
