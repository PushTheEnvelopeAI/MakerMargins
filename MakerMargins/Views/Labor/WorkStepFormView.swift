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

    // Stopwatch
    @State private var showingStopwatch = false
    @State private var titleHasBeenTouched = false

    // Focus tracking for select-on-tap behavior
    enum FocusableField: Hashable {
        case title, summary
        case hours, minutes, seconds
        case batchUnits, unitName
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

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty
            || batchUnits <= 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                PhotoPickerSection(imageData: $imageData, photoItem: $photoItem)
                detailsSection
                timeAndBatchSection
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onChange(of: photoItem) { _, newItem in
                loadPhoto(from: newItem)
            }
            .onChange(of: focusedField) { oldField, newField in
                if let oldField { fieldDefault(for: oldField).restoreOnBlur() }
                if let newField { fieldDefault(for: newField).clearOnFocus() }
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
                StopwatchView(
                    stepTitle: title.isEmpty ? nil : title,
                    unitName: unitName.isEmpty ? "unit" : unitName,
                    currentBatchUnits: Decimal(string: batchUnitsText) ?? 1
                ) { time, units in
                    let total = Int(time)
                    hoursText = total >= 3600 ? "\(total / 3600)" : ""
                    minutesText = "\((total % 3600) / 60)"
                    secondsText = "\(total % 60)"
                    batchUnitsText = "\(units)"
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    private var hasUnsavedChanges: Bool {
        if step != nil {
            let total = Int(step?.recordedTime ?? 0)
            let origH = total >= 3600 ? "\(total / 3600)" : ""
            let origM = "\((total % 3600) / 60)"
            let origS = "\(total % 60)"
            return title != (step?.title ?? "")
                || summary != (step?.summary ?? "")
                || hoursText != origH
                || minutesText != origM
                || secondsText != origS
                || batchUnitsText != "\(step?.batchUnitsCompleted ?? 1)"
                || unitName != (step?.unitName ?? "unit")
                || imageData != step?.image
        } else {
            return !title.trimmingCharacters(in: .whitespaces).isEmpty
                || !summary.trimmingCharacters(in: .whitespaces).isEmpty
                || recordedTime > 0
                || imageData != nil
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section("Details") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                TextField("Title", text: $title)
                    .focused($focusedField, equals: .title)
                    .onTapGesture { titleHasBeenTouched = true }
                if titleHasBeenTouched && title.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Title is required")
                        .font(AppTheme.Typography.rowCaption)
                        .foregroundStyle(AppTheme.Colors.destructive)
                }
            }
            TextField("Description", text: $summary, axis: .vertical)
                .focused($focusedField, equals: .summary)
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
                Text("Time to Complete Batch")
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
                HStack(spacing: AppTheme.Spacing.xs) {
                    timeField(text: $hoursText, label: "h", field: .hours)
                    Text(":")
                        .font(AppTheme.Typography.formSectionValue)
                        .foregroundStyle(.tertiary)
                    timeField(text: $minutesText, label: "m", field: .minutes)
                    Text(":")
                        .font(AppTheme.Typography.formSectionValue)
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
                    Text("Units per Batch")
                    Spacer()
                    TextField("1", text: $batchUnitsText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: AppTheme.Sizing.inputMedium)
                        .focused($focusedField, equals: .batchUnits)
                }
                Text("Number of \(displayUnitName)s produced in this batch")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text("Unit Name")
                    Spacer()
                    TextField("unit", text: $unitName)
                        .multilineTextAlignment(.trailing)
                        .frame(width: AppTheme.Sizing.inputLarge)
                        .focused($focusedField, equals: .unitName)
                }
                Text("What you call each piece (e.g. board, piece, widget)")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }

        } header: {
            Text("Time & Batch")
        }
    }

    private var previewSection: some View {
        Section("Calculated") {
            let unitTimeSeconds: TimeInterval = batchUnits > 0
                ? recordedTime / Double(truncating: batchUnits as NSDecimalNumber)
                : 0
            let hoursPerUnit = CostingEngine.unitTimeHours(
                recordedTime: recordedTime,
                batchUnitsCompleted: batchUnits
            )

            previewRow(label: "Time per \(displayUnitName)", value: CostingEngine.formatDuration(unitTimeSeconds))

            VStack(spacing: AppTheme.Spacing.xs) {
                HStack {
                    Text("Hours per \(displayUnitName)")
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    Text(CostingEngine.formatHours(hoursPerUnit))
                        .font(AppTheme.Typography.derivedValue)
                        .foregroundStyle(AppTheme.Colors.accent)
                }
                Text("This is the key efficiency metric for this step")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                .frame(width: AppTheme.Sizing.inputTime)
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

    private func fieldDefault(for field: FocusableField) -> FormFieldDefault {
        switch field {
        case .title:
            FormFieldDefault(get: { title }, set: { title = $0 }, defaultValue: "")
        case .summary:
            FormFieldDefault(get: { summary }, set: { summary = $0 }, defaultValue: "")
        case .hours:
            FormFieldDefault(get: { hoursText }, set: { hoursText = $0 }, defaultValue: "")
        case .minutes:
            FormFieldDefault(get: { minutesText }, set: { minutesText = $0 }, defaultValue: "0")
        case .seconds:
            FormFieldDefault(get: { secondsText }, set: { secondsText = $0 }, defaultValue: "0")
        case .batchUnits:
            FormFieldDefault(get: { batchUnitsText }, set: { batchUnitsText = $0 }, defaultValue: "1")
        case .unitName:
            FormFieldDefault(get: { unitName }, set: { unitName = $0 }, defaultValue: "unit")
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
        } else {
            // Create new step + link to product
            let newStep = WorkStep(
                title: trimmedTitle,
                summary: trimmedSummary,
                image: imageData,
                recordedTime: recordedTime,
                batchUnitsCompleted: safeBatchUnits,
                unitName: unitName.trimmingCharacters(in: .whitespaces).isEmpty ? "unit" : unitName.trimmingCharacters(in: .whitespaces)
            )
            modelContext.insert(newStep)

            if let product {
                let link = ProductWorkStep(
                    product: product,
                    workStep: newStep,
                    sortOrder: product.productWorkSteps.count,
                    unitsRequiredPerProduct: newStep.defaultUnitsPerProduct,
                    laborRate: laborRateManager.defaultRate
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
