// PricingCalculatorView.swift
// MakerMargins
//
// Inline target price calculator rendered within ProductDetailView.
// Tabbed by platform (General, Etsy, Shopify, Amazon). Each tab auto-pulls
// the product's costs, shows locked platform fees, and lets the user adjust
// editable pricing settings. The target retail price updates live.
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

    // Text fields for editable values (displayed as whole numbers for percentages)
    @State private var transactionFeeText: String = ""
    @State private var fixedFeeText: String = ""
    @State private var marketingFeeRateText: String = ""
    @State private var percentSalesFromMarketingText: String = ""
    @State private var profitMarginText: String = ""

    private enum FocusableField: Hashable {
        case transactionFee, fixedFee, marketingFeeRate, percentSalesFromMarketing, profitMargin
    }
    @FocusState private var focusedField: FocusableField?

    // MARK: - Computed

    private var productionCost: Decimal {
        CostingEngine.totalProductionCost(product: product)
    }

    private var fees: (transactionFee: Decimal, fixedFee: Decimal,
                       marketingFeeRate: Decimal, percentSalesFromMarketing: Decimal,
                       profitMargin: Decimal) {
        guard let pricing = currentPricing else {
            return (0, 0, 0, 0, Decimal(string: "0.30")!)
        }
        return CostingEngine.resolvedFees(
            platformType: selectedPlatform,
            userTransactionFee: pricing.transactionFeePercentage,
            userFixedFee: pricing.fixedFeePerSale,
            userMarketingFeeRate: pricing.marketingFeeRate,
            userPercentSalesFromMarketing: pricing.percentSalesFromMarketing,
            userProfitMargin: pricing.profitMargin
        )
    }

    private var effectiveMarketing: Decimal {
        CostingEngine.effectiveMarketingRate(
            marketingFeeRate: fees.marketingFeeRate,
            percentSalesFromMarketing: fees.percentSalesFromMarketing
        )
    }

    private var computedTargetPrice: Decimal? {
        let f = fees
        return CostingEngine.targetRetailPrice(
            product: product,
            transactionFee: f.transactionFee,
            fixedFee: f.fixedFee,
            marketingFeeRate: f.marketingFeeRate,
            percentSalesFromMarketing: f.percentSalesFromMarketing,
            profitMargin: f.profitMargin
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            GroupBox("Target Price Calculator") {
                VStack(spacing: 0) {
                    platformPicker
                    Divider()

                    if productionCost == 0 {
                        emptyCostHint
                    } else {
                        costSection
                    }

                    Divider()
                    lockedFeesSection
                    editableFieldsSection
                    Divider()
                    effectiveMarketingRow
                    Divider()
                    targetPriceRow
                }
            }

            Text("Select a platform to see your target price based on production costs, fees, and profit margin. Switch tabs to compare across platforms.")
                .font(AppTheme.Typography.note)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, AppTheme.Spacing.xs)
        }
        .padding(.horizontal)
        .onAppear { loadPricing() }
        .onChange(of: selectedPlatform) { _, _ in
            loadPricing()
        }
        .onChange(of: fixedFeeText) { _, newValue in
            let value = Decimal(string: newValue) ?? 0
            currentPricing?.fixedFeePerSale = value >= 0 ? value : 0
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

    private var emptyCostHint: some View {
        HStack {
            Spacer()
            VStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Add materials, labor, or shipping costs to calculate pricing.")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, AppTheme.Spacing.lg)
            Spacer()
        }
    }

    private var costSection: some View {
        VStack(spacing: 0) {
            DetailRow(
                label: "Material Cost",
                value: formatter.format(CostingEngine.totalMaterialCostBuffered(product: product))
            )
            Divider()
            DetailRow(
                label: "Labor Cost",
                value: formatter.format(CostingEngine.totalLaborCostBuffered(product: product))
            )
            Divider()
            DetailRow(
                label: "Shipping Cost",
                value: formatter.format(product.shippingCost)
            )
            Divider()
            DerivedRow(
                label: "Production Cost",
                value: formatter.format(productionCost)
            )
        }
    }

    @ViewBuilder
    private var lockedFeesSection: some View {
        let descriptions = selectedPlatform.lockedFeeDescriptions
        if !descriptions.isEmpty {
            Divider()
            VStack(spacing: 0) {
                HStack {
                    Text("Platform Fees")
                        .font(AppTheme.Typography.note)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.top, AppTheme.Spacing.sm)

                ForEach(descriptions, id: \.label) { fee in
                    HStack {
                        Text(fee.label)
                            .font(AppTheme.Typography.bodyText)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(fee.value)
                            .font(AppTheme.Typography.bodyText)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                }
            }
        }
    }

    @ViewBuilder
    private var editableFieldsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your Settings")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.top, AppTheme.Spacing.sm)

            if selectedPlatform.isTransactionFeeEditable {
                PercentageInputField(
                    label: "Transaction Fee",
                    text: $transactionFeeText,
                    field: FocusableField.transactionFee,
                    focusBinding: $focusedField,
                    writeBack: { currentPricing?.transactionFeePercentage = $0 }
                )
                .padding(.vertical, AppTheme.Spacing.xs)
            }

            if selectedPlatform.isFixedFeeEditable {
                HStack {
                    Text("Fixed Fee / Sale")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    CurrencyInputField(
                        symbol: formatter.symbol,
                        text: $fixedFeeText
                    )
                    .editableFieldStyle()
                    .focused($focusedField, equals: .fixedFee)
                }
                .padding(.vertical, AppTheme.Spacing.xs)
            }

            if selectedPlatform.isMarketingFeeRateEditable {
                PercentageInputField(
                    label: "Marketing Fee",
                    text: $marketingFeeRateText,
                    field: FocusableField.marketingFeeRate,
                    focusBinding: $focusedField,
                    writeBack: { currentPricing?.marketingFeeRate = $0 }
                )
                .padding(.vertical, AppTheme.Spacing.xs)
            }

            PercentageInputField(
                label: selectedPlatform.marketingFeeLabel,
                text: $percentSalesFromMarketingText,
                field: FocusableField.percentSalesFromMarketing,
                focusBinding: $focusedField,
                writeBack: { currentPricing?.percentSalesFromMarketing = $0 }
            )
            .padding(.vertical, AppTheme.Spacing.xs)

            PercentageInputField(
                label: "Profit Margin",
                text: $profitMarginText,
                field: FocusableField.profitMargin,
                focusBinding: $focusedField,
                writeBack: { currentPricing?.profitMargin = $0 }
            )
            .padding(.vertical, AppTheme.Spacing.xs)
        }
    }

    private var effectiveMarketingRow: some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            HStack {
                Text("Effective Marketing")
                    .font(AppTheme.Typography.bodyText)
                Spacer()
                Text(PercentageFormat.toDisplay(effectiveMarketing) + "%")
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(AppTheme.Colors.accent)
            }
            .padding(.vertical, AppTheme.Spacing.sm)

            Text("Marketing fee rate × % of sales from marketing")
                .font(AppTheme.Typography.note)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, AppTheme.Spacing.xs)
        }
    }

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

    // MARK: - Data Loading

    /// Finds or lazily creates the ProductPricing for the current product and selected platform.
    private func loadPricing() {
        if let existing = product.productPricings.first(where: { $0.platformType == selectedPlatform }) {
            currentPricing = existing
        } else {
            let defaults = fetchDefaults(for: selectedPlatform)
            let pricing = ProductPricing(
                product: product,
                platformType: selectedPlatform,
                transactionFeePercentage: defaults.transactionFeePercentage,
                fixedFeePerSale: defaults.fixedFeePerSale,
                marketingFeeRate: defaults.marketingFeeRate,
                percentSalesFromMarketing: defaults.percentSalesFromMarketing,
                profitMargin: defaults.profitMargin
            )
            modelContext.insert(pricing)
            currentPricing = pricing
        }
        loadFieldTexts()
    }

    /// Fetches the PlatformFeeProfile defaults for a platform, or returns system defaults.
    private func fetchDefaults(for platform: PlatformType) -> PlatformFeeProfile {
        let allProfiles = (try? modelContext.fetch(FetchDescriptor<PlatformFeeProfile>())) ?? []
        if let existing = allProfiles.first(where: { $0.platformType == platform }) {
            return existing
        }
        return PlatformFeeProfile(platformType: platform)
    }

    /// Populates text fields from the current pricing record.
    private func loadFieldTexts() {
        guard let pricing = currentPricing else { return }
        transactionFeeText = PercentageFormat.toDisplay(pricing.transactionFeePercentage)
        fixedFeeText = "\(pricing.fixedFeePerSale)"
        marketingFeeRateText = PercentageFormat.toDisplay(pricing.marketingFeeRate)
        percentSalesFromMarketingText = PercentageFormat.toDisplay(pricing.percentSalesFromMarketing)
        profitMarginText = PercentageFormat.toDisplay(pricing.profitMargin)
    }

    // MARK: - Focus Handling

    /// Handles clear-on-focus and restore-on-blur for all fields.
    private func handleFocusChange(_ newField: FocusableField?) {
        let fields: [(text: Binding<String>, defaultValue: String, field: FocusableField)] = [
            ($transactionFeeText, "0", .transactionFee),
            ($fixedFeeText, "0", .fixedFee),
            ($marketingFeeRateText, "0", .marketingFeeRate),
            ($percentSalesFromMarketingText, "0", .percentSalesFromMarketing),
            ($profitMarginText, "0", .profitMargin),
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
