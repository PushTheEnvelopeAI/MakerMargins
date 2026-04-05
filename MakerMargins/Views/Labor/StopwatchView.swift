// StopwatchView.swift
// MakerMargins
//
// Full-screen stopwatch for timing a production batch.
// Presented as .fullScreenCover from WorkStepDetailView or WorkStepFormView.
// Uses an onSave closure so the caller decides what to do with the elapsed time.
// Supports pause/resume — accumulated time is tracked across multiple intervals.
// When paused, shows a batch units field. Save is disabled until units > 0.

import SwiftUI

struct StopwatchView: View {
    var stepTitle: String? = nil
    var unitName: String = "unit"
    var currentBatchUnits: Decimal = 1
    let onSave: (TimeInterval, Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var timerState: TimerState = .idle
    @State private var startDate: Date? = nil
    @State private var accumulatedTime: TimeInterval = 0
    @State private var showingDiscardConfirmation = false
    @State private var batchUnitsText: String = ""
    @FocusState private var batchUnitsFocused: Bool

    private enum TimerState {
        case idle, running, paused
    }

    private var parsedBatchUnits: Decimal {
        Decimal(string: batchUnitsText) ?? 0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Spacer()
            VStack(spacing: AppTheme.Spacing.sm) {
                timeDisplay
                if let stepTitle {
                    Text("Timing: \(stepTitle)")
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            buttons
                .padding(.bottom, AppTheme.Spacing.xl * 2)
        }
        .appBackground()
        .confirmationDialog("Stop Timer?", isPresented: $showingDiscardConfirmation) {
            Button("Stop and Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Timing", role: .cancel) { }
        } message: {
            Text("The timer is still running. Your recorded time will not be saved.")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Spacer()
            Button {
                if timerState == .running {
                    showingDiscardConfirmation = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .accessibilityLabel("Close stopwatch")
        }
    }

    // MARK: - Time Display

    @ViewBuilder
    private var timeDisplay: some View {
        if timerState == .running {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let live = accumulatedTime + (startDate.map { context.date.timeIntervalSince($0) } ?? 0)
                Text(CostingEngine.formatStopwatchTime(live))
                    .font(AppTheme.Typography.timerDisplay)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .accessibilityLabel(CostingEngine.accessibleTimeDescription(live))
            }
        } else {
            Text(CostingEngine.formatStopwatchTime(accumulatedTime))
                .font(AppTheme.Typography.timerDisplay)
                .accessibilityLabel(CostingEngine.accessibleTimeDescription(accumulatedTime))
        }
    }

    // MARK: - Buttons

    @ViewBuilder
    private var buttons: some View {
        switch timerState {
        case .idle:
            Button(action: start) {
                stopwatchButton(label: "Start", style: .accent)
            }

        case .running:
            Button(action: pause) {
                stopwatchButton(label: "Pause", style: .destructive)
            }

        case .paused:
            VStack(spacing: AppTheme.Spacing.lg) {
                // Batch units input — visible immediately when paused
                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("\(unitName.capitalized)s produced")
                        .font(AppTheme.Typography.sectionHeader)
                        .foregroundStyle(.secondary)

                    TextField("0", text: $batchUnitsText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(AppTheme.Typography.heroPrice)
                        .frame(width: 120)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.inputBackground, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                        .focused($batchUnitsFocused)
                        .accessibilityLabel("\(unitName)s produced in this batch")

                    if parsedBatchUnits <= 0 {
                        Text("Enter units produced to save")
                            .font(AppTheme.Typography.rowCaption)
                            .foregroundStyle(AppTheme.Colors.destructive)
                    }
                }

                HStack(spacing: AppTheme.Spacing.xl) {
                    Button(action: resume) {
                        stopwatchButton(label: "Resume", style: .accent)
                    }
                    Button(action: confirmSave) {
                        stopwatchButton(label: "Save", style: .secondary)
                    }
                    .disabled(parsedBatchUnits <= 0)
                }
                HStack(spacing: AppTheme.Spacing.xl) {
                    Button("Discard", action: discard)
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Button("Re-record", action: rerecord)
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Button Style Helper

    private enum StopwatchButtonVariant {
        case accent, destructive, secondary
    }

    @ViewBuilder
    private func stopwatchButton(label: String, style: StopwatchButtonVariant) -> some View {
        Text(label)
            .font(.title3.weight(.semibold))
            .frame(width: AppTheme.Sizing.stopwatchButtonWidth, height: AppTheme.Sizing.stopwatchButtonHeight)
            .foregroundStyle(.white)
            .background(buttonColor(for: style), in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }

    private func buttonColor(for style: StopwatchButtonVariant) -> Color {
        switch style {
        case .accent: return AppTheme.Colors.accent
        case .destructive: return AppTheme.Colors.destructive
        case .secondary: return AppTheme.Colors.secondaryButton
        }
    }

    // MARK: - Actions

    private func start() {
        startDate = Date.now
        timerState = .running
        AccessibilityNotification.Announcement("Timer started").post()
    }

    private func pause() {
        if let startDate {
            accumulatedTime += Date.now.timeIntervalSince(startDate)
        }
        startDate = nil
        timerState = .paused
        AccessibilityNotification.Announcement("Timer paused").post()
    }

    private func resume() {
        startDate = Date.now
        timerState = .running
        AccessibilityNotification.Announcement("Timer resumed").post()
    }

    private func confirmSave() {
        let units = parsedBatchUnits > 0 ? parsedBatchUnits : 1
        onSave(accumulatedTime, units)
        dismiss()
    }

    private func discard() {
        dismiss()
    }

    private func rerecord() {
        accumulatedTime = 0
        startDate = nil
        batchUnitsText = ""
        timerState = .idle
        AccessibilityNotification.Announcement("Timer reset").post()
    }
}
