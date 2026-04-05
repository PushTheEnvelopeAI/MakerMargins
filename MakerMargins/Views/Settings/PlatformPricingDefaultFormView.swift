// PlatformPricingDefaultFormView.swift
// MakerMargins
//
// Single universal form for default pricing settings.
// Pushed directly from SettingsView. All fields are percentages.
// These defaults pre-fill editable fields across all platform tabs
// in the Target Price Calculator (locked platform fees are never overridden).
// Changes save immediately to a single PlatformFeeProfile record.

import SwiftUI
import SwiftData

struct PlatformPricingDefaultFormView: View {
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var profile: PlatformFeeProfile?

    @State private var platformFeeText: String = ""
    @State private var paymentProcessingFeeText: String = ""
    @State private var marketingFeeText: String = ""
    @State private var percentSalesFromMarketingText: String = ""
    @State private var profitMarginText: String = ""

    /// Stores the value before clearing on focus, for restore on blur if user leaves empty.
    @State private var previousValue: String = ""

    enum FocusableField: Hashable {
        case platformFee, paymentProcessingFee, marketingFee, percentSalesFromMarketing, profitMargin
    }
    @FocusState private var focusedField: FocusableField?

    // MARK: - Body

    var body: some View {
        List {
            Section {
                PercentageInputField(
                    label: "Platform Fee",
                    text: $platformFeeText,
                    field: FocusableField.platformFee,
                    focusBinding: $focusedField,
                    writeBack: { profile?.platformFee = $0 }
                )

                PercentageInputField(
                    label: "Transaction Fees",
                    text: $paymentProcessingFeeText,
                    field: FocusableField.paymentProcessingFee,
                    focusBinding: $focusedField,
                    writeBack: { profile?.paymentProcessingFee = $0 }
                )

                PercentageInputField(
                    label: "Marketing Fee",
                    text: $marketingFeeText,
                    field: FocusableField.marketingFee,
                    focusBinding: $focusedField,
                    writeBack: { profile?.marketingFee = $0 }
                )

                PercentageInputField(
                    label: "% of Sales from Ads",
                    text: $percentSalesFromMarketingText,
                    field: FocusableField.percentSalesFromMarketing,
                    focusBinding: $focusedField,
                    writeBack: { profile?.percentSalesFromMarketing = $0 }
                )

                Text("What fraction of your sales come through paid advertising?")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)

                PercentageInputField(
                    label: "Profit Margin",
                    text: $profitMarginText,
                    field: FocusableField.profitMargin,
                    focusBinding: $focusedField,
                    writeBack: { profile?.profitMargin = $0 }
                )
            } header: {
                Text("Defaults")
            } footer: {
                Text("These defaults pre-fill editable fields in the Target Price Calculator for all platforms. Platform-specific locked fees are not affected.")
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Pricing Defaults")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onAppear { loadProfile() }
        .onChange(of: focusedField) { _, newField in
            handleFocusChange(newField)
        }
    }

    // MARK: - Helpers

    /// Fetches or lazily creates the single PlatformFeeProfile defaults record.
    private func loadProfile() {
        let allProfiles = (try? modelContext.fetch(FetchDescriptor<PlatformFeeProfile>())) ?? []
        if let existing = allProfiles.first {
            profile = existing
        } else {
            let newProfile = PlatformFeeProfile()
            modelContext.insert(newProfile)
            profile = newProfile
        }
        loadFieldTexts()
    }

    /// Populates text fields from the current profile.
    private func loadFieldTexts() {
        guard let profile else { return }
        platformFeeText = PercentageFormat.toDisplay(profile.platformFee)
        paymentProcessingFeeText = PercentageFormat.toDisplay(profile.paymentProcessingFee)
        marketingFeeText = PercentageFormat.toDisplay(profile.marketingFee)
        percentSalesFromMarketingText = PercentageFormat.toDisplay(profile.percentSalesFromMarketing)
        profitMarginText = PercentageFormat.toDisplay(profile.profitMargin)
    }

    /// Clears the focused field's value for easy override; restores previous value on blur if left empty.
    private func handleFocusChange(_ newField: FocusableField?) {
        let fields: [(text: Binding<String>, field: FocusableField)] = [
            ($platformFeeText, .platformFee),
            ($paymentProcessingFeeText, .paymentProcessingFee),
            ($marketingFeeText, .marketingFee),
            ($percentSalesFromMarketingText, .percentSalesFromMarketing),
            ($profitMarginText, .profitMargin),
        ]

        for f in fields {
            if newField == f.field {
                // Clear on focus — store current value for potential restore
                previousValue = f.text.wrappedValue
                f.text.wrappedValue = ""
            } else {
                // Restore on blur if user left it empty
                if f.text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    f.text.wrappedValue = previousValue.isEmpty ? "0" : previousValue
                }
            }
        }
    }
}
