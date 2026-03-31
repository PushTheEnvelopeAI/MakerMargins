// ViewModifiers.swift
// MakerMargins
//
// Reusable view modifiers and helper views that use AppTheme tokens.

import SwiftUI
import PhotosUI

// MARK: - Card Style

extension View {
    /// Applies the standard elevated-card background with medium corner radius.
    func cardStyle() -> some View {
        self
            .background(
                AppTheme.Colors.surfaceElevated,
                in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .strokeBorder(AppTheme.Colors.cardBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
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

// MARK: - Material Thumbnail

/// Reusable thumbnail for materials in list rows.
/// Shows the material's image or a placeholder with a shipping box icon.
struct MaterialThumbnailView: View {
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
                    Image(systemName: "shippingbox")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
        }
    }
}

// MARK: - Product Thumbnail

/// Reusable thumbnail for products in list rows and "Used By" sections.
/// Shows the product's image or a placeholder with a photo icon.
struct ProductThumbnailView: View {
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
                    Image(systemName: "photo")
                        .font(.caption2)
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

// MARK: - Editable Field Style

extension View {
    /// Applies a subtle rounded background to indicate an editable/tappable input field.
    /// Use on inline TextFields and CurrencyInputFields in detail views and product sections.
    func editableFieldStyle() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.smd)
            .background(
                AppTheme.Colors.inputBackground,
                in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
            )
    }
}

// MARK: - Currency Input Field

/// Reusable currency input that groups symbol + TextField + optional suffix
/// into a visually cohesive unit. Used for labor rate, bulk cost, etc.
struct CurrencyInputField: View {
    let symbol: String
    @Binding var text: String
    var suffix: String? = nil
    var width: CGFloat = AppTheme.Sizing.inputMedium
    var focusBinding: FocusState<Bool>.Binding? = nil

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            Text(symbol)
                .foregroundStyle(.secondary)
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: width)
            if let suffix {
                Text(suffix)
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Detail Rows

/// Standard detail row for displaying a label–value pair in a GroupBox.
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.bodyText)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.sectionHeader)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}

/// Detail row where the value is a derived/calculated value shown in accent color.
struct DerivedRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.bodyText)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.sectionHeader)
                .foregroundStyle(AppTheme.Colors.accent)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}

// MARK: - Photo Picker Section

/// Reusable image picker section for create/edit forms.
/// Shows a circular thumbnail or camera placeholder, with add/change/remove actions.
struct PhotoPickerSection: View {
    @Binding var imageData: Data?
    @Binding var photoItem: PhotosPickerItem?

    var body: some View {
        let currentImage: UIImage? = imageData.flatMap { UIImage(data: $0) }
        let hasImage = currentImage != nil
        Section {
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
}

// MARK: - Usage Text

/// Shared helper for "Used by X + N others" text across list and library views.
enum UsageText {
    static func from(products: [Product]) -> String {
        guard let first = products.first else { return "Not used" }
        let remaining = products.count - 1
        if remaining == 0 {
            return "Used by \(first.title)"
        }
        return "Used by \(first.title) + \(remaining) \(remaining == 1 ? "other" : "others")"
    }
}

// MARK: - Form Field Default

/// Encapsulates clear-on-focus / restore-on-blur behavior for a form text field.
/// Each field has a known default value (e.g. "0", "1", "unit") that is cleared
/// when the user taps the field and restored if they leave it empty.
struct FormFieldDefault {
    let get: () -> String
    let set: (String) -> Void
    let defaultValue: String

    func clearOnFocus() {
        if get() == defaultValue { set("") }
    }

    func restoreOnBlur() {
        if get().trimmingCharacters(in: .whitespaces).isEmpty { set(defaultValue) }
    }
}
