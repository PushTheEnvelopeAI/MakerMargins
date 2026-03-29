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
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
}

// MARK: - App Background

extension View {
    /// Applies the warm page-level background.
    func appBackground() -> some View {
        self.background(AppTheme.Colors.surface)
    }
}

// MARK: - Work Step Thumbnail

/// Reusable thumbnail for work steps in list rows.
/// Shows the step's image or a placeholder with a wrench icon.
struct WorkStepThumbnailView: View {
    let imageData: Data?
    var size: CGFloat = AppTheme.Sizing.thumbnailSmall

    var body: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        } else {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .fill(AppTheme.Colors.placeholder)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
        }
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
