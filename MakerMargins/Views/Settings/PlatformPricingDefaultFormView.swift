// PlatformPricingDefaultFormView.swift
// MakerMargins
//
// Editable defaults form for a single platform type's pricing settings.
// Pushed from PlatformPricingDefaultsView. Shows locked platform fees as
// read-only context and editable fields for user-configurable values.
// Changes save immediately to the PlatformFeeProfile model.
// The profile is created lazily on first access.

import SwiftUI
import SwiftData

struct PlatformPricingDefaultFormView: View {
    let platformType: PlatformType

    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyFormatter) private var formatter

    // MARK: - State

    @State private var profile: PlatformFeeProfile?

    // Text fields for editable values (displayed as whole numbers for percentages)
    @State private var transactionFeeText: String = ""
    @State private var fixedFeeText: String = ""
    @State private var marketingFeeRateText: String = ""
    @State private var percentSalesFromMarketingText: String = ""
    @State private var profitMarginText: String = ""

    enum FocusableField: Hashable {
        case transactionFee, fixedFee, marketingFeeRate, percentSalesFromMarketing, profitMargin
    }
    @FocusState private var focusedField: FocusableField?

    // MARK: - Body

    var body: some View {
        List {
            // Read-only locked fees section (non-General platforms only)
            if !platformType.lockedFeeDescriptions.isEmpty {
                Section {
                    ForEach(platformType.lockedFeeDescriptions, id: \.label) { fee in
                        HStack {
                            Text(fee.label)
                                .font(AppTheme.Typography.bodyText)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text(fee.value)
                                .font(AppTheme.Typography.bodyText)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("Platform Fees")
                } footer: {
                    Text("These fees are set by \(platformType.rawValue) and cannot be changed.")
                }
            }

            // Editable defaults section
            Section {
                if platformType.isTransactionFeeEditable {
                    PercentageInputField(
                        label: "Transaction Fee",
                        text: $transactionFeeText,
                        field: FocusableField.transactionFee,
                        focusBinding: $focusedField,
                        writeBack: { profile?.transactionFeePercentage = $0 }
                    )
                }

                if platformType.isFixedFeeEditable {
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
                }

                if platformType.isMarketingFeeRateEditable {
                    PercentageInputField(
                        label: "Marketing Fee",
                        text: $marketingFeeRateText,
                        field: FocusableField.marketingFeeRate,
                        focusBinding: $focusedField,
                        writeBack: { profile?.marketingFeeRate = $0 }
                    )
                }

                PercentageInputField(
                    label: platformType.marketingFeeLabel,
                    text: $percentSalesFromMarketingText,
                    field: FocusableField.percentSalesFromMarketing,
                    focusBinding: $focusedField,
                    writeBack: { profile?.percentSalesFromMarketing = $0 }
                )

                PercentageInputField(
                    label: "Profit Margin",
                    text: $profitMarginText,
                    field: FocusableField.profitMargin,
                    focusBinding: $focusedField,
                    writeBack: { profile?.profitMargin = $0 }
                )
            } header: {
                Text("Your Defaults")
            } footer: {
                Text("These defaults pre-fill pricing for new products on \(platformType.rawValue). You can override them per product in the Target Price Calculator.")
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("\(platformType.rawValue) Defaults")
        .onAppear { loadProfile() }
        .onChange(of: fixedFeeText) { _, newValue in
            let value = Decimal(string: newValue) ?? 0
            profile?.fixedFeePerSale = value >= 0 ? value : 0
        }
        .onChange(of: focusedField) { _, newField in
            handleFocusChange(newField)
        }
    }

    // MARK: - Helpers

    /// Fetches or lazily creates the PlatformFeeProfile for this platform type.
    private func loadProfile() {
        let allProfiles = (try? modelContext.fetch(FetchDescriptor<PlatformFeeProfile>())) ?? []
        if let existing = allProfiles.first(where: { $0.platformType == platformType }) {
            profile = existing
        } else {
            let newProfile = PlatformFeeProfile(platformType: platformType)
            modelContext.insert(newProfile)
            profile = newProfile
        }
        loadFieldTexts()
    }

    /// Populates text fields from the current profile.
    private func loadFieldTexts() {
        guard let profile else { return }
        transactionFeeText = PercentageFormat.toDisplay(profile.transactionFeePercentage)
        fixedFeeText = "\(profile.fixedFeePerSale)"
        marketingFeeRateText = PercentageFormat.toDisplay(profile.marketingFeeRate)
        percentSalesFromMarketingText = PercentageFormat.toDisplay(profile.percentSalesFromMarketing)
        profitMarginText = PercentageFormat.toDisplay(profile.profitMargin)
    }

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
