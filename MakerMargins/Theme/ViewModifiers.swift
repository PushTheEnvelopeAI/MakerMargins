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
            .shadow(color: AppTheme.Shadow.color, radius: AppTheme.Shadow.radius, x: AppTheme.Shadow.x, y: AppTheme.Shadow.y)
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
                .accessibilityHidden(true)
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
                .accessibilityHidden(true)
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
                .accessibilityHidden(true)
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

// MARK: - Item Header View

/// Shared image + summary header for WorkStep and Material detail views.
struct ItemHeaderView: View {
    let imageData: Data?
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: AppTheme.Sizing.detailImageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
                    .padding(.horizontal)
            } else {
                PlaceholderImageView(
                    height: AppTheme.Sizing.detailPlaceholderHeight,
                    cornerRadius: AppTheme.CornerRadius.large,
                    iconFont: .largeTitle
                )
                .padding(.horizontal)
            }

            if !summary.isEmpty {
                Text(summary)
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Used By Section

/// Shared "Used By" section showing linked products for WorkStep and Material detail views.
/// When product is nil (library context), products are tappable NavigationLinks.
struct UsedBySection: View {
    let linkedProducts: [Product]
    let product: Product?
    let emptyText: String

    var body: some View {
        GroupBox("Used By") {
            if linkedProducts.isEmpty {
                HStack {
                    Text(emptyText)
                        .font(AppTheme.Typography.bodyText)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, AppTheme.Spacing.xs)
            } else {
                VStack(spacing: 0) {
                    ForEach(linkedProducts, id: \.persistentModelID) { linkedProduct in
                        if product == nil {
                            NavigationLink(value: linkedProduct) {
                                HStack(spacing: AppTheme.Spacing.md) {
                                    ProductThumbnailView(imageData: linkedProduct.image)
                                    Text(linkedProduct.title)
                                        .font(AppTheme.Typography.rowTitle)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                        .accessibilityHidden(true)
                                }
                                .padding(.vertical, AppTheme.Spacing.sm)
                            }
                            .buttonStyle(.plain)
                        } else {
                            HStack(spacing: AppTheme.Spacing.md) {
                                ProductThumbnailView(imageData: linkedProduct.image)
                                Text(linkedProduct.title)
                                    .font(AppTheme.Typography.rowTitle)
                                Spacer()
                            }
                            .padding(.vertical, AppTheme.Spacing.sm)
                        }

                        if linkedProduct.persistentModelID != linkedProducts.last?.persistentModelID {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Remove From Product Button

/// Shared destructive button for removing a step or material from a product.
struct RemoveFromProductButton: View {
    let productTitle: String
    let onRemove: () -> Void

    var body: some View {
        Button(role: .destructive) {
            onRemove()
        } label: {
            HStack {
                Spacer()
                Label("Remove from \(productTitle)", systemImage: "minus.circle")
                    .font(AppTheme.Typography.bodyText)
                Spacer()
            }
            .padding(.vertical, AppTheme.Spacing.md)
            .background(
                AppTheme.Colors.destructive.opacity(0.1),
                in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .strokeBorder(AppTheme.Colors.destructive.opacity(0.3), lineWidth: 0.5)
            )
        }
        .padding(.horizontal)
    }
}

// MARK: - Item Row

/// Shared row layout for items in WorkStep and Material list views.
/// Shows thumbnail + title + cost subtitle + detail subtitle + chevron.
struct ItemRow<Thumbnail: View>: View {
    let thumbnail: Thumbnail
    let title: String
    let costText: String
    let detailText: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            thumbnail

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(title)
                    .font(AppTheme.Typography.rowTitle)
                    .lineLimit(1)
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(costText)
                        .font(AppTheme.Typography.rowCaption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(detailText)
                        .font(AppTheme.Typography.rowCaption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}

// MARK: - Reorder Row

/// Shared reorder row for WorkStep and Material list views.
/// Shows thumbnail + title + up/down arrow buttons.
struct ReorderRow<Thumbnail: View>: View {
    let thumbnail: Thumbnail
    let title: String
    let index: Int
    let total: Int
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            thumbnail

            Text(title)
                .font(AppTheme.Typography.rowTitle)
                .lineLimit(1)

            Spacer()

            Button(action: onMoveUp) {
                Image(systemName: "arrow.up")
                    .font(.caption.weight(.semibold))
            }
            .disabled(index == 0)
            .frame(minWidth: 44, minHeight: 44)
            .buttonStyle(.bordered)
            .accessibilityLabel("Move \(title) up")

            Button(action: onMoveDown) {
                Image(systemName: "arrow.down")
                    .font(.caption.weight(.semibold))
            }
            .disabled(index == total - 1)
            .frame(minWidth: 44, minHeight: 44)
            .buttonStyle(.bordered)
            .accessibilityLabel("Move \(title) down")
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}

// MARK: - Buffer Input Section

/// Reusable buffer percentage input with label, helper text, focus behavior, and buffered total.
/// Used for Labor Cost Buffer and Material Cost Buffer in list views.
struct BufferInputSection: View {
    let label: String
    let helperText: String
    let totalLabel: String
    let totalValue: Decimal
    @Binding var bufferText: String
    var focusBinding: FocusState<Bool>.Binding
    let onBufferChanged: (Decimal) -> Void

    @Environment(\.currencyFormatter) private var formatter

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Divider()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text(label)
                        .font(AppTheme.Typography.bodyText)
                    Spacer()
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        TextField("0", text: $bufferText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: AppTheme.Sizing.inputBuffer)
                            .focused(focusBinding)
                        Text("%")
                            .font(AppTheme.Typography.bodyText)
                            .foregroundStyle(.secondary)
                    }
                    .editableFieldStyle()
                }
                Text(helperText)
                    .font(AppTheme.Typography.note)
                    .foregroundStyle(.tertiary)
            }
            .onChange(of: bufferText) { _, _ in
                onBufferChanged(PercentageFormat.fromDisplay(bufferText))
            }
            .onChange(of: focusBinding.wrappedValue) { _, focused in
                if focused {
                    if bufferText == "0" { bufferText = "" }
                } else {
                    if bufferText.trimmingCharacters(in: .whitespaces).isEmpty { bufferText = "0" }
                }
            }

            HStack {
                Text(totalLabel)
                    .font(AppTheme.Typography.sectionHeader)
                Spacer()
                Text(formatter.format(totalValue))
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }
        .padding(.top, AppTheme.Spacing.xs)
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

// MARK: - Calculator Section Header

/// Reusable section header with SF Symbol icon for pricing calculator sections.
struct CalculatorSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.smd) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(AppTheme.Typography.sectionLabel)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Calculator Section Styles

extension View {
    /// Wraps content in a subtle grouped background for calculator row sections.
    func sectionGroupStyle() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(
                AppTheme.Colors.sectionFill,
                in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
            )
    }

    /// Hero card treatment for key output values (Target Price, Profit per Sale).
    func heroCardStyle() -> some View {
        self
            .padding(AppTheme.Spacing.md)
            .background(
                AppTheme.Colors.accentSubtle,
                in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
            )
            .accessibilityElement(children: .combine)
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

// MARK: - Percentage Helpers

/// Converts a stored fraction (e.g. 0.30) to a display string (e.g. "30").
/// Strips unnecessary trailing zeros; returns whole number when possible.
enum PercentageFormat {
    static func toDisplay(_ value: Decimal) -> String {
        let whole = value * 100
        let double = NSDecimalNumber(decimal: whole).doubleValue
        if double == double.rounded(.towardZero) {
            return "\(Int(double))"
        }
        // Round to 1 decimal place for computed values with many decimal places
        let rounded = (double * 10).rounded() / 10
        if rounded == rounded.rounded(.towardZero) {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }

    /// Converts a display string (e.g. "30") to a stored fraction (e.g. 0.30).
    /// Returns 0 for invalid or negative input.
    static func fromDisplay(_ text: String) -> Decimal {
        guard let value = Decimal(string: text), value >= 0 else { return 0 }
        return value / 100
    }
}

/// Reusable percentage input that groups TextField + "%" suffix into a cohesive unit.
/// Mirrors CurrencyInputField but for percentage values.
struct PercentageInputField<Field: Hashable>: View {
    let label: String
    @Binding var text: String
    let field: Field
    var focusBinding: FocusState<Field?>.Binding
    let writeBack: (Decimal) -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.bodyText)
            Spacer()
            HStack(spacing: AppTheme.Spacing.xxs) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: AppTheme.Sizing.inputMedium)
                    .focused(focusBinding, equals: field)
                Text("%")
                    .font(AppTheme.Typography.bodyText)
                    .foregroundStyle(.secondary)
            }
            .editableFieldStyle()
        }
        .onChange(of: text) { _, newValue in
            writeBack(PercentageFormat.fromDisplay(newValue))
        }
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
