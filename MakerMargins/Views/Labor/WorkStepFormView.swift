// WorkStepFormView.swift
// MakerMargins
//
// Create / edit sheet for a WorkStep.
// Pass nil to create a new step; pass an existing WorkStep to edit it
// (changes propagate to all products using the step).
// Pass a Product to link the new step; pass nil to create a standalone library step.
// All fields are held in local @State — never bound directly to the model —
// so changes only persist when the user taps Save.

import SwiftUI
import SwiftData
import PhotosUI

struct WorkStepFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.laborRateManager) private var laborRateManager
    @Environment(\.currencyFormatter) private var currencyFormatter

    let step: WorkStep?
    let product: Product?

    // MARK: - Form state

    @State private var title: String
    @State private var summary: String

    // Image
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil

    // Time (broken into h/m/s for user-friendly entry)
    @State private var hoursText: String
    @State private var minutesText: String
    @State private var secondsText: String

    // Batch
    @State private var batchUnitsText: String
    @State private var unitName: String
    @State private var unitsPerProductText: String

    // Cost
    @State private var laborRateText: String

    // Stopwatch
    @State private var showingStopwatch = false

    // Focus tracking for select-on-tap behavior
    enum FocusableField: Hashable {
        case hours, minutes, seconds
        case batchUnits, unitName, unitsPerProduct
        case laborRate
    }
    @FocusState private var focusedField: FocusableField?

    // MARK: - Init

    init(step: WorkStep?, product: Product?) {
        self.step = step
        self.product = product

        _title = State(initialValue: step?.title ?? "")
        _summary = State(initialValue: step?.summary ?? "")
        _imageData = State(initialValue: step?.image)

        // Break recordedTime (seconds) into h/m/s
        let total = Int(step?.recordedTime ?? 0)
        _hoursText = State(initialValue: total >= 3600 ? "\(total / 3600)" : "")
        _minutesText = State(initialValue: "\((total % 3600) / 60)")
        _secondsText = State(initialValue: "\(total % 60)")

        _batchUnitsText = State(initialValue: "\(step?.batchUnitsCompleted ?? 1)")
        _unitName = State(initialValue: step?.unitName ?? "unit")
        _unitsPerProductText = State(initialValue: "\(step?.unitsRequiredPerProduct ?? 1)")

        // Labor rate: for new steps this will be overridden in onAppear
        // to use the LaborRateManager default
        _laborRateText = State(initialValue: step != nil ? "\(step!.laborRate)" : "")
    }

    // MARK: - Computed

    private var recordedTime: TimeInterval {
        let h = Double(hoursText) ?? 0
        let m = Double(minutesText) ?? 0
        let s = Double(secondsText) ?? 0
        return (h * 3600) + (m * 60) + s
    }

    private var batchUnits: Decimal {
        Decimal(string: batchUnitsText) ?? 1
    }

    private var unitsPerProduct: Decimal {
        Decimal(string: unitsPerProductText) ?? 1
    }

    private var laborRate: Decimal {
        Decimal(string: laborRateText) ?? 0
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty
            || batchUnits <= 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                imageSection
                detailsSection
                timeAndBatchSection
                costSection
                previewSection
            }
            .navigationTitle(step == nil ? "New Work Step" : "Edit Work Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaveDisabled)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                loadPhoto(from: newItem)
            }
            .onAppear {
                if step == nil && laborRateText.isEmpty {
                    laborRateText = "\(laborRateManager.defaultRate)"
                }
            }
            .onChange(of: focusedField) { oldField, newField in
                // Restore defaults on blur for fields left empty
                if let oldField {
                    restoreDefaultIfEmpty(field: oldField)
                }
                // Clear default values on focus so user can type fresh
                if let newField {
                    clearDefaultOnFocus(field: newField)
                }
            }
            .onChange(of: hoursText) { _, newValue in
                hoursText = sanitizeDigitsOnly(newValue)
            }
            .onChange(of: minutesText) { _, newValue in
                minutesText = clampTimeComponent(sanitizeDigitsOnly(newValue), max: 59)
            }
            .onChange(of: secondsText) { _, newValue in
                secondsText = clampTimeComponent(sanitizeDigitsOnly(newValue), max: 59)
            }
            .fullScreenCover(isPresented: $showingStopwatch) {
                StopwatchView(stepTitle: title.isEmpty ? nil : title) { time in
                    let total = Int(time)
                    hoursText = total >= 3600 ? "\(total / 3600)" : ""
                    minutesText = "\((total % 3600) / 60)"
                    secondsText = "\(total % 60)"
                }
            }
        }
    }

    // MARK: - Sections

    private var imageSection: some View {
        let currentImage: UIImage? = imageData.flatMap { UIImage(data: $0) }
        let hasImage = currentImage != nil
        return Section {
            PhotosPicker(selection: $photoItem, matching: .images) {
                VStack(spacing: AppTheme.Spacing.sm) {
                    if let uiImage = currentImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: AppTheme.Sizing.thumbnailForm, height: AppTheme.Sizing.thumbnailForm)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(AppTheme.Colors.placeholder)
                            .frame(width: AppTheme.Sizing.thumbnailForm, height: AppTheme.Sizing.thumbnailForm)
                            .overlay {
                                Image(systemName: "camera")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                    Text(hasImage ? "Change Photo" : "Add Photo")
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.tint)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.sm)
            }
            .buttonStyle(.plain)

            if hasImage {
                Button("Remove Photo", role: .destructive) {
                    imageData = nil
                    photoItem = nil
                }
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $title)
            TextField("Description", text: $summary, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var displayUnitName: String {
        let name = unitName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "unit" : name
    }

    private var timeAndBatchSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Recorded Time")
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
                HStack(spacing: AppTheme.Spacing.xs) {
                    timeField(text: $hoursText, label: "h", field: .hours)
                    Text(":")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    timeField(text: $minutesText, label: "m", field: .minutes)
                    Text(":")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    timeField(text: $secondsText, label: "s", field: .seconds)
                }
                Text("Total time to produce the batch")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }

            Button {
                showingStopwatch = true
            } label: {
                Label("Use Stopwatch", systemImage: "stopwatch")
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text("\(displayUnitName.capitalized)s Completed")
                    Spacer()
                    TextField("1", text: $batchUnitsText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($focusedField, equals: .batchUnits)
                }
                Text("How many \(displayUnitName)s were produced in this timed batch")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text("Unit Name")
                    Spacer()
                    TextField("unit", text: $unitName)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .focused($focusedField, equals: .unitName)
                }
                Text("What you call each piece (e.g. board, piece, widget)")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text("\(displayUnitName.capitalized)s per Product")
                    Spacer()
                    TextField("1", text: $unitsPerProductText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($focusedField, equals: .unitsPerProduct)
                }
                Text("How many \(displayUnitName)s go into one finished product")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
        } header: {
            Text("Time & Batch")
        }
    }

    private var costSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text("Hourly Rate")
                    Spacer()
                    Text(currencyFormatter.selected == .usd ? "$" : "€")
                        .foregroundStyle(.secondary)
                    TextField("0", text: $laborRateText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($focusedField, equals: .laborRate)
                    Text("/hr")
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.secondary)
                }
                Text("Defaults to your rate in Settings; override per step here")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
        } header: {
            Text("Cost")
        }
    }

    private var previewSection: some View {
        Section("Calculated") {
            let unitTimeSeconds: TimeInterval = batchUnits > 0
                ? recordedTime / Double(truncating: batchUnits as NSDecimalNumber)
                : 0
            let timePerProduct = unitTimeSeconds * Double(truncating: unitsPerProduct as NSDecimalNumber)
            let cost = CostingEngine.stepLaborCost(
                recordedTime: recordedTime,
                batchUnitsCompleted: batchUnits,
                unitsRequiredPerProduct: unitsPerProduct,
                laborRate: laborRate
            )

            previewRow(label: "Time per \(displayUnitName)", value: CostingEngine.formatDuration(unitTimeSeconds))
            previewRow(label: "Time per product", value: CostingEngine.formatDuration(timePerProduct))

            HStack {
                Text("Labor cost per product")
                    .font(AppTheme.Typography.bodyText)
                Spacer()
                Text(currencyFormatter.format(cost))
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func timeField(text: Binding<String>, label: String, field: FocusableField) -> some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
                .focused($focusedField, equals: field)
            Text(label)
                .font(AppTheme.Typography.bodyText)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func previewRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.bodyText)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.sectionHeader)
                .foregroundStyle(AppTheme.Colors.accent)
        }
    }

    // MARK: - Focus & Validation Helpers

    private func clearDefaultOnFocus(field: FocusableField) {
        switch field {
        case .hours:
            if hoursText == "0" || hoursText.isEmpty { hoursText = "" }
        case .minutes:
            if minutesText == "0" { minutesText = "" }
        case .seconds:
            if secondsText == "0" { secondsText = "" }
        case .batchUnits:
            if batchUnitsText == "1" { batchUnitsText = "" }
        case .unitName:
            if unitName == "unit" { unitName = "" }
        case .unitsPerProduct:
            if unitsPerProductText == "1" { unitsPerProductText = "" }
        case .laborRate:
            if laborRateText == "0" { laborRateText = "" }
        }
    }

    private func restoreDefaultIfEmpty(field: FocusableField) {
        switch field {
        case .hours:
            if hoursText.trimmingCharacters(in: .whitespaces).isEmpty { hoursText = "" }
        case .minutes:
            if minutesText.trimmingCharacters(in: .whitespaces).isEmpty { minutesText = "0" }
        case .seconds:
            if secondsText.trimmingCharacters(in: .whitespaces).isEmpty { secondsText = "0" }
        case .batchUnits:
            if batchUnitsText.trimmingCharacters(in: .whitespaces).isEmpty { batchUnitsText = "1" }
        case .unitName:
            if unitName.trimmingCharacters(in: .whitespaces).isEmpty { unitName = "unit" }
        case .unitsPerProduct:
            if unitsPerProductText.trimmingCharacters(in: .whitespaces).isEmpty { unitsPerProductText = "1" }
        case .laborRate:
            if laborRateText.trimmingCharacters(in: .whitespaces).isEmpty { laborRateText = "0" }
        }
    }

    private func sanitizeDigitsOnly(_ value: String) -> String {
        let filtered = value.filter { $0.isNumber }
        return filtered == value ? value : filtered
    }

    private func clampTimeComponent(_ value: String, max: Int) -> String {
        guard let intValue = Int(value), intValue > max else { return value }
        return "\(max)"
    }

    // MARK: - Actions

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespaces)
        let safeBatchUnits = batchUnits > 0 ? batchUnits : 1

        if let step {
            // Edit existing — changes propagate to all products using this step
            step.title = trimmedTitle
            step.summary = trimmedSummary
            step.image = imageData
            step.recordedTime = recordedTime
            step.batchUnitsCompleted = safeBatchUnits
            step.unitName = unitName.trimmingCharacters(in: .whitespaces).isEmpty ? "unit" : unitName.trimmingCharacters(in: .whitespaces)
            step.unitsRequiredPerProduct = unitsPerProduct > 0 ? unitsPerProduct : 1
            step.laborRate = laborRate
        } else {
            // Create new step + link to product
            let newStep = WorkStep(
                title: trimmedTitle,
                summary: trimmedSummary,
                image: imageData,
                laborRate: laborRate,
                recordedTime: recordedTime,
                batchUnitsCompleted: safeBatchUnits,
                unitName: unitName.trimmingCharacters(in: .whitespaces).isEmpty ? "unit" : unitName.trimmingCharacters(in: .whitespaces),
                unitsRequiredPerProduct: unitsPerProduct > 0 ? unitsPerProduct : 1
            )
            modelContext.insert(newStep)

            if let product {
                let link = ProductWorkStep(
                    product: product,
                    workStep: newStep,
                    sortOrder: product.productWorkSteps.count
                )
                modelContext.insert(link)
                product.productWorkSteps.append(link)
                newStep.productWorkSteps.append(link)
            }
        }
        dismiss()
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task { @MainActor in
            imageData = try? await item.loadTransferable(type: Data.self)
        }
    }
}
