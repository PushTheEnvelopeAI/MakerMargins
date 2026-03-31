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
                    label: "Payment Processing",
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
                    label: "% Sales from Ads",
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
                Text("Defaults")
            } footer: {
                Text("These defaults pre-fill editable fields in the Target Price Calculator for all platforms. Platform-specific locked fees are not affected.")
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Pricing Defaults")
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

    /// Handles clear-on-focus and restore-on-blur for all fields.
    private func handleFocusChange(_ newField: FocusableField?) {
        let fields: [(text: Binding<String>, defaultValue: String, field: FocusableField)] = [
            ($platformFeeText, "0", .platformFee),
            ($paymentProcessingFeeText, "0", .paymentProcessingFee),
            ($marketingFeeText, "0", .marketingFee),
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
