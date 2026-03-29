// ViewModifiers.swift
// MakerMargins
//
// Reusable view modifiers and helper views that use AppTheme tokens.

import SwiftUI

// MARK: - Card Style

extension View {
    /// Applies the standard elevated-card background with medium corner radius.
    func cardStyle() -> some View {
        self
            .background(
                AppTheme.Colors.surfaceElevated,
                in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
            )
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Placeholder Image

/// Reusable placeholder for missing images.
/// Shows a rounded rectangle with a centered "photo" SF Symbol.
struct PlaceholderImageView: View {
    var height: CGFloat
    var cornerRadius: CGFloat = AppTheme.CornerRadius.medium
    var iconFont: Font = .title2

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppTheme.Colors.placeholder)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                Image(systemName: "photo")
                    .font(iconFont)
                    .foregroundStyle(.tertiary)
            }
    }
}
