// StopwatchView.swift
// MakerMargins
//
// Full-screen stopwatch for timing a production batch.
// Presented as .fullScreenCover from WorkStepDetailView or WorkStepFormView.
// Uses an onSave closure so the caller decides what to do with the elapsed time.
// Timer uses Date.now diff for accuracy (not accumulated intervals).

import SwiftUI

struct StopwatchView: View {
    var stepTitle: String? = nil
    let onSave: (TimeInterval) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var timerState: TimerState = .idle
    @State private var startDate: Date? = nil
    @State private var elapsed: TimeInterval = 0

    private enum TimerState {
        case idle, running, stopped
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
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Spacer()
            if timerState != .running {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }

    // MARK: - Time Display

    @ViewBuilder
    private var timeDisplay: some View {
        if timerState == .running {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let live = startDate.map { context.date.timeIntervalSince($0) } ?? 0
                Text(formatStopwatch(live))
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .contentTransition(.numericText())
            }
        } else {
            Text(formatStopwatch(elapsed))
                .font(.system(size: 56, weight: .light, design: .monospaced))
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
            Button(action: stop) {
                stopwatchButton(label: "Stop", style: .destructive)
            }

        case .stopped:
            VStack(spacing: AppTheme.Spacing.lg) {
                HStack(spacing: AppTheme.Spacing.xl) {
                    Button(action: discard) {
                        stopwatchButton(label: "Discard", style: .secondary)
                    }
                    Button(action: save) {
                        stopwatchButton(label: "Save", style: .accent)
                    }
                }
                Button("Re-record", action: rerecord)
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
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
            .frame(width: 130, height: 54)
            .foregroundStyle(.white)
            .background(buttonColor(for: style), in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }

    private func buttonColor(for style: StopwatchButtonVariant) -> Color {
        switch style {
        case .accent: return AppTheme.Colors.accent
        case .destructive: return .red
        case .secondary: return .gray
        }
    }

    // MARK: - Time Formatting

    private func formatStopwatch(_ seconds: TimeInterval) -> String {
        let total = max(0, seconds)
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        let s = Int(total) % 60
        let tenths = Int((total - Double(Int(total))) * 10)

        if h > 0 {
            return String(format: "%d:%02d:%02d.%d", h, m, s, tenths)
        }
        return String(format: "%02d:%02d.%d", m, s, tenths)
    }

    // MARK: - Actions

    private func start() {
        startDate = Date.now
        timerState = .running
    }

    private func stop() {
        if let startDate {
            elapsed = Date.now.timeIntervalSince(startDate)
        }
        timerState = .stopped
    }

    private func save() {
        onSave(elapsed)
        dismiss()
    }

    private func discard() {
        dismiss()
    }

    private func rerecord() {
        elapsed = 0
        startDate = nil
        timerState = .idle
    }
}
