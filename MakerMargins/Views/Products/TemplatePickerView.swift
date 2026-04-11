// TemplatePickerView.swift
// MakerMargins
//
// Sheet for selecting a starter product template.
// Displays all templates as tappable cards in a 2-column grid.
// Tapping a card calls TemplateApplier to create the product and
// fires the onProductCreated callback for post-creation navigation.

import SwiftUI
import SwiftData

struct TemplatePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analyticsManager) private var analyticsManager

    /// Called with the newly created Product after template application.
    var onProductCreated: ((Product) -> Void)?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                templateGrid
            }
            .appBackground()
            .navigationTitle("Start from Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Grid

    private var templateGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppTheme.Spacing.lg),
                GridItem(.flexible())
            ],
            spacing: AppTheme.Spacing.lg
        ) {
            ForEach(ProductTemplates.all, id: \.id) { template in
                Button {
                    applyTemplate(template)
                } label: {
                    TemplateCardView(template: template)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(template.title): \(template.summary)")
                .accessibilityHint("Creates a product from this template")
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func applyTemplate(_ template: ProductTemplate) {
        do {
            let product = try TemplateApplier.apply(template, to: modelContext)
            analyticsManager.signal(.templateApplied, payload: ["templateId": template.id])
            onProductCreated?(product)
            dismiss()
        } catch {
            // Template data is controlled and valid. Only a corrupted store
            // would cause a failure here — silent failure is acceptable.
        }
    }
}

// MARK: - TemplateCardView

private struct TemplateCardView: View {
    let template: ProductTemplate

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: template.iconName)
                .font(AppTheme.Typography.templateIcon)
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(height: AppTheme.Sizing.templateIconHeight)

            VStack(spacing: AppTheme.Spacing.xs) {
                Text(template.title)
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(template.summary)
                    .font(AppTheme.Typography.gridCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("\(template.workSteps.count) steps, \(template.materials.count) materials, Etsy pricing")
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: AppTheme.Sizing.gridCellHeight)
        .cardStyle()
    }
}
