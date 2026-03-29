// Theme.swift
// MakerMargins
//
// Centralized design tokens for the MakerMargins UI.
// Provides semantic colors, spacing, corner radii, and shadow properties
// with automatic light/dark mode support.
//
// Injected via EnvironmentKey and accessed via @Environment(\.theme).
// All views must use theme tokens — never hardcode colors inline.

import SwiftUI

// MARK: - Theme

struct Theme {

    // MARK: - Brand / Accent

    /// Primary brand color: warm honey amber
    var accent: Color { Color(hex: 0xC4853A) }

    /// Lighter tint for badge/chip backgrounds
    var accentSoft: Color { Color(hex: 0xC4853A).opacity(0.15) }

    // MARK: - Surfaces

    /// Main page background — warm off-white / warm near-black
    var canvas: Color { Color(light: Color(hex: 0xFAF6F1), dark: Color(hex: 0x1C1916)) }

    /// Card / grouped section background
    var surface: Color { Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x262220)) }

    /// Elevated card background (cost summary)
    var surfaceElevated: Color { Color(light: Color(hex: 0xFFF9F2), dark: Color(hex: 0x302B27)) }

    /// Placeholder fills, input backgrounds
    var fill: Color { Color(light: Color(hex: 0xF0E8DD), dark: Color(hex: 0x3A3430)) }

    /// Lighter placeholder fill
    var fillSubtle: Color { Color(light: Color(hex: 0xF5EFE7), dark: Color(hex: 0x2E2924)) }

    // MARK: - Text

    /// Primary text — warm dark brown
    var textPrimary: Color { Color(light: Color(hex: 0x2C2017), dark: Color(hex: 0xF0E8DD)) }

    /// Secondary labels
    var textSecondary: Color { Color(light: Color(hex: 0x7A6B5D), dark: Color(hex: 0xA89888)) }

    /// Faintest labels
    var textTertiary: Color { Color(light: Color(hex: 0xAA9D90), dark: Color(hex: 0x6B5F54)) }

    // MARK: - Semantic / Functional

    /// Positive / profit — forest green
    var profit: Color { Color(hex: 0x4A8C5C) }

    /// Warning / low margin — warm amber
    var caution: Color { Color(hex: 0xD4903E) }

    /// Destructive / loss — muted terracotta red
    var loss: Color { Color(hex: 0xC45544) }

    // MARK: - Chips

    /// Selected filter chip background
    var chipSelected: Color { Color(hex: 0xC4853A) }

    /// Unselected filter chip background
    var chipDefault: Color { Color(light: Color(hex: 0xEDE5DA), dark: Color(hex: 0x3A3430)) }

    // MARK: - Spacing

    var spacingXS: CGFloat { 4 }
    var spacingS: CGFloat { 8 }
    var spacingM: CGFloat { 12 }
    var spacingL: CGFloat { 16 }
    var spacingXL: CGFloat { 20 }

    // MARK: - Corner Radii

    var radiusS: CGFloat { 8 }
    var radiusM: CGFloat { 12 }
    var radiusL: CGFloat { 16 }
    var radiusXL: CGFloat { 20 }

    // MARK: - Shadows

    var shadowColor: Color { Color.black.opacity(0.08) }
    var shadowRadius: CGFloat { 8 }
    var shadowY: CGFloat { 2 }

    // MARK: - Card

    var cardCornerRadius: CGFloat { 16 }
}

// MARK: - Color Helpers

extension Color {
    /// Create a color from a hex value (e.g. 0xC4853A).
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Create an adaptive color that switches between light and dark appearances.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Environment

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme()
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
