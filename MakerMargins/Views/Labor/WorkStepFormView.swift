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

    private var timeAndBatchSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Recorded Time")
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
                HStack(spacing: AppTheme.Spacing.xs) {
                    timeField(text: $hoursText, label: "h")
                    Text(":")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    timeField(text: $minutesText, label: "m")
                    Text(":")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    timeField(text: $secondsText, label: "s")
                }
            }

            Button {
                showingStopwatch = true
            } label: {
                Label("Use Stopwatch", systemImage: "stopwatch")
            }

            HStack {
                Text("Units Completed")
                Spacer()
                TextField("1", text: $batchUnitsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Unit Name")
                Spacer()
                TextField("unit", text: $unitName)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }

            HStack {
                Text("Units per Product")
                Spacer()
                TextField("1", text: $unitsPerProductText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
        } header: {
            Text("Time & Batch")
        } footer: {
            Text("Enter the total time for a batch, how many items you produced, and how many are needed per finished product.")
        }
    }

    private var costSection: some View {
        Section {
            HStack {
                Text("Hourly Rate")
                Spacer()
                Text(currencyFormatter.selected == .usd ? "$" : "€")
                    .foregroundStyle(.secondary)
                TextField("0", text: $laborRateText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("/hr")
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Cost")
        } footer: {
            Text("The hourly labor rate for this step. Defaults to your rate in Settings; you can adjust it here for this step.")
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

            previewRow(label: "Time per \(unitName)", value: CostingEngine.formatDuration(unitTimeSeconds))
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
    private func timeField(text: Binding<String>, label: String) -> some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
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
        }
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
