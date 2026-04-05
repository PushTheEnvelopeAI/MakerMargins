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

    /// Total labor hours across all work steps for this product.
    private var totalLaborHours: Decimal {
        CostingEngine.totalLaborHours(product: product)
    }

    /// Take-home per labor hour, or nil when hours = 0.
    private var computedTakeHomePerHour: Decimal? {
        CostingEngine.takeHomePerHour(product: product, actualProfit: computedActualProfit)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            GroupBox("Target Price Calculator") {
                VStack(spacing: AppTheme.Spacing.md) {
                    platformPicker
                    productionCostSection
                    marketingAndFeesSection
                    profitMarginSection
                    targetPriceHero
                }
            }
            .backgroundStyle(AppTheme.Colors.pricingSurface)

            // Visual separator between the two calculator tools
            HStack(spacing: AppTheme.Spacing.sm) {
                VStack { Divider() }
                Text("YOUR ACTUAL RESULTS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .layoutPriority(1)
                VStack { Divider() }
            }
            .padding(.vertical, AppTheme.Spacing.sm)

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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
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
        VStack(spacing: AppTheme.Spacing.xs) {
            CalculatorSectionHeader(title: "Production Costs", icon: "hammer")

            if productionCost == 0 {
                emptyCostHint
            } else {
                VStack(spacing: 0) {
                    DetailRow(
                        label: "Material Cost",
                        value: formatter.format(CostingEngine.totalMaterialCostBuffered(product: product))
                    )
                    DetailRow(
                        label: "Labor Cost",
                        value: formatter.format(CostingEngine.totalLaborCostBuffered(product: product))
                    )
                    DetailRow(
                        label: "Shipping Cost",
                        value: formatter.format(product.shippingCost)
                    )
                    HStack {
                        Text("Total")
                            .font(AppTheme.Typography.sectionHeader)
                        Spacer()
                        Text(formatter.format(productionCost))
                            .font(AppTheme.Typography.sectionHeader)
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                    .padding(.vertical, AppTheme.Spacing.sm)
                }
                .sectionGroupStyle()
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
        .sectionGroupStyle()
    }

    // MARK: Marketing and Fees

    private var marketingAndFeesSection: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            CalculatorSectionHeader(title: "Marketing and Fees", icon: "percent")

            VStack(spacing: AppTheme.Spacing.xxs) {
                feeRow(
                    label: "Platform Fee",
                    lockedDisplay: selectedPlatform.platformFeeDisplay,
                    text: $platformFeeText,
                    field: .platformFee,
                    writeBack: { currentPricing?.platformFee = $0 }
                )

                feeRow(
                    label: "Payment Processing",
                    lockedDisplay: selectedPlatform.paymentProcessingDisplay,
                    text: $paymentProcessingFeeText,
                    field: .paymentProcessingFee,
                    writeBack: { currentPricing?.paymentProcessingFee = $0 }
                )

                feeRow(
                    label: "Marketing Fees",
                    lockedDisplay: selectedPlatform.marketingFeeDisplay,
                    text: $marketingFeeText,
                    field: .marketingFee,
                    writeBack: { currentPricing?.marketingFee = $0 }
                )

                PercentageInputField(
                    label: "% Sales from Ads",
                    text: $percentSalesFromMarketingText,
                    field: FocusableField.percentSalesFromMarketing,
                    focusBinding: $focusedField,
                    writeBack: { currentPricing?.percentSalesFromMarketing = $0 }
                )
                .padding(.vertical, AppTheme.Spacing.xs)

                // Total Fees subtotal
                let f = resolved
                let effectiveMktg = CostingEngine.effectiveMarketingRate(
                    marketingFee: f.marketingFee,
                    percentSalesFromMarketing: f.percentSalesFromMarketing
                )
                let totalPercentFees = f.platformFee + f.paymentProcessingFee + effectiveMktg
                HStack {
                    Text("Total Fees")
                        .font(AppTheme.Typography.sectionHeader)
                    Spacer()
                    Text("\(PercentageFormat.toDisplay(totalPercentFees))%")
                        .font(AppTheme.Typography.sectionHeader)
                        .foregroundStyle(AppTheme.Colors.accent)
                }
                .padding(.vertical, AppTheme.Spacing.sm)

                if f.paymentProcessingFixed > 0 {
                    Text("+ \(formatter.format(f.paymentProcessingFixed)) per transaction")
                        .font(AppTheme.Typography.note)
                        .foregroundStyle(.tertiary)
                }
            }
            .sectionGroupStyle()
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
                HStack(spacing: AppTheme.Spacing.xs) {
                    Text(display)
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.tertiary)
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                        .accessibilityLabel("Locked by platform")
                }
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

    private var profitMarginSection: some View {
        PercentageInputField(
            label: "Profit Margin",
            text: $profitMarginText,
            field: FocusableField.profitMargin,
            focusBinding: $focusedField,
            writeBack: { currentPricing?.profitMargin = $0 }
        )
        .padding(.vertical, AppTheme.Spacing.xs)
        .sectionGroupStyle()
    }

    // MARK: Target Price

    private var targetPriceHero: some View {
        HStack {
            Text("Target Price")
                .font(AppTheme.Typography.sectionHeader)
            Spacer()
            if let price = computedTargetPrice {
                Text(formatter.format(price))
                    .font(AppTheme.Typography.heroPrice)
                    .foregroundStyle(AppTheme.Colors.accent)
            } else {
                Text("— (fees too high)")
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(.red)
            }
        }
        .heroCardStyle()
    }

    // MARK: - Profit Analysis

    private var profitAnalysisGroupBox: some View {
        GroupBox("Profit Analysis") {
            VStack(spacing: AppTheme.Spacing.md) {
                actualPricingSection

                if hasActualPrice {
                    profitBreakdownSection
                    Divider()
                        .padding(.vertical, AppTheme.Spacing.xs)
                    profitHeroSection
                } else if computedTargetPrice != nil {
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
        VStack(spacing: AppTheme.Spacing.xs) {
            CalculatorSectionHeader(title: "Your Actual Pricing", icon: "dollarsign.circle")

            VStack(spacing: AppTheme.Spacing.xxs) {
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
            .sectionGroupStyle()
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
        VStack(spacing: AppTheme.Spacing.xs) {
            CalculatorSectionHeader(title: "Breakdown", icon: "list.bullet.rectangle")

            VStack(spacing: 0) {
                DetailRow(
                    label: "Revenue",
                    value: formatter.format(grossRevenue)
                )

                let f = resolved

                let platformFeeAmount = grossRevenue * f.platformFee
                if platformFeeAmount > 0 {
                    DetailRow(
                        label: "Platform Fees",
                        value: "-\(formatter.format(platformFeeAmount))"
                    )
                    .foregroundStyle(.secondary)
                }

                let processingAmount = grossRevenue * f.paymentProcessingFee + f.paymentProcessingFixed
                if processingAmount > 0 {
                    DetailRow(
                        label: "Processing Fees",
                        value: "-\(formatter.format(processingAmount))"
                    )
                    .foregroundStyle(.secondary)
                }

                let effectiveMarketing = CostingEngine.effectiveMarketingRate(
                    marketingFee: f.marketingFee,
                    percentSalesFromMarketing: f.percentSalesFromMarketing
                )
                let marketingAmount = (currentPricing?.actualPrice ?? 0) * effectiveMarketing
                if marketingAmount > 0 {
                    DetailRow(
                        label: "Marketing Fees",
                        value: "-\(formatter.format(marketingAmount))"
                    )
                    .foregroundStyle(.secondary)
                }

                let prodCost = CostingEngine.productionCostExShipping(product: product)
                DetailRow(
                    label: "Production Cost",
                    value: "-\(formatter.format(prodCost))"
                )
                .foregroundStyle(.secondary)

                if product.shippingCost > 0 {
                    DetailRow(
                        label: "Your Shipping Cost",
                        value: "-\(formatter.format(product.shippingCost))"
                    )
                    .foregroundStyle(.secondary)
                }

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
            .sectionGroupStyle()
        }
    }

    private var profitHeroSection: some View {
        let laborCost = CostingEngine.totalLaborCostBuffered(product: product)
        let earnings = computedActualProfit + laborCost
        let hasLabor = laborCost > 0

        return VStack(spacing: AppTheme.Spacing.xs) {
            VStack(spacing: AppTheme.Spacing.sm) {
                // Your Earnings / Sale — single hero metric
                HStack {
                    Text("Your Earnings / Sale")
                        .font(AppTheme.Typography.sectionHeader)
                    Spacer()
                    Text(formatter.format(earnings))
                        .font(AppTheme.Typography.heroPrice)
                        .foregroundStyle(earnings >= 0 ? AppTheme.Colors.accent : .red)
                }

                // Breakdown: Margin After Costs + Your Labor (hidden when no labor — would be redundant with hero)
                if hasLabor {
                    HStack {
                        Text("Margin After Costs")
                            .font(AppTheme.Typography.bodyText)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatter.format(computedActualProfit))
                            .font(AppTheme.Typography.bodyText)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("+ Your Labor")
                            .font(AppTheme.Typography.bodyText)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatter.format(laborCost))
                            .font(AppTheme.Typography.bodyText)
                            .foregroundStyle(.secondary)
                    }
                }

                // Profit Margin
                if let margin = computedActualProfitMargin {
                    HStack {
                        Text("Profit Margin")
                            .font(AppTheme.Typography.bodyText)
                        Spacer()
                        Text("\(PercentageFormat.toDisplay(margin))%")
                            .font(AppTheme.Typography.sectionHeader)
                            .foregroundStyle(earnings >= 0 ? AppTheme.Colors.accent : .red)
                    }
                }

                // Effective Hourly Rate — only when labor hours exist
                if let perHour = computedTakeHomePerHour {
                    HStack {
                        Text("Effective Hourly Rate")
                            .font(AppTheme.Typography.bodyText)
                        Spacer()
                        Text("\(formatter.format(perHour)) / hr")
                            .font(AppTheme.Typography.sectionHeader)
                            .foregroundStyle(earnings >= 0 ? AppTheme.Colors.accent : .red)
                    }
                }
            }
            .heroCardStyle()

            // Shipping absorbed callout
            if let pricing = currentPricing,
               pricing.actualShippingCharge == 0,
               product.shippingCost > 0 {
                shippingAbsorbedCallout
            }
        }
    }

    private var shippingAbsorbedCallout: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityLabel("Info")
            Text("You're absorbing \(formatter.format(product.shippingCost)) in shipping costs on this platform.")
                .font(AppTheme.Typography.note)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .sectionGroupStyle()
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
