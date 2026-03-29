// AppTheme.swift
// MakerMargins
//
// Centralised design tokens for the entire app.
// All views reference AppTheme.* instead of hardcoded literals.

import SwiftUI

enum AppTheme {

    // MARK: - Colors

    enum Colors {
        /// Primary brand color — warm amber. Used for tint, buttons, selected chips.
        static let accent = Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.88, green: 0.58, blue: 0.13, alpha: 1)   // #E09422
                    : UIColor(red: 0.76, green: 0.47, blue: 0.09, alpha: 1)   // #C17817
            }
        )

        /// Subtle accent background — badges, tag pills.
        static let accentSubtle = Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.88, green: 0.58, blue: 0.13, alpha: 0.20)
                    : UIColor(red: 0.76, green: 0.47, blue: 0.09, alpha: 0.12)
            }
        )

        /// Elevated surface — grid cells, cards. Warm tinted.
        static let surfaceElevated = Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.11, green: 0.10, blue: 0.09, alpha: 1)   // #1C1A17
                    : UIColor(red: 1.00, green: 0.98, blue: 0.96, alpha: 1)   // #FFFBF5
            }
        )

        /// Placeholder backgrounds for missing images.
        static let placeholder = Color(.tertiarySystemFill)

        /// Unselected chip / filter background.
        static let chipBackground = Color(.secondarySystemFill)
    }

    // MARK: - Spacing (4-pt grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 20
    }

    // MARK: - Corner Radii

    enum CornerRadius {
        static let small:  CGFloat = 8
        static let medium: CGFloat = 12
        static let large:  CGFloat = 16
    }

    // MARK: - Typography

    enum Typography {
        static let gridTitle:     Font = .subheadline.weight(.medium)
        static let gridCaption:   Font = .caption2
        static let rowTitle:      Font = .body
        static let rowCaption:    Font = .caption
        static let sectionHeader: Font = .subheadline.weight(.semibold)
        static let bodyText:      Font = .subheadline
        static let badge:         Font = .caption.weight(.medium)
        static let note:          Font = .caption2
    }

    // MARK: - Sizing

    enum Sizing {
        static let thumbnailSmall:        CGFloat = 48
        static let thumbnailForm:         CGFloat = 100
        static let gridImageHeight:       CGFloat = 160
        static let gridMinColumn:         CGFloat = 160
        static let detailImageHeight:     CGFloat = 240
        static let detailPlaceholderHeight: CGFloat = 160
    }
}
