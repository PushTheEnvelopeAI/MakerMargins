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

        /// Subtle accent background — interactive highlights, selected states.
        static let accentSubtle = Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.88, green: 0.58, blue: 0.13, alpha: 0.20)
                    : UIColor(red: 0.76, green: 0.47, blue: 0.09, alpha: 0.12)
            }
        )

        /// Category badge text — sage/olive green.
        static let categoryBadge = Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.58, green: 0.70, blue: 0.52, alpha: 1)      // #94B385
                    : UIColor(red: 0.42, green: 0.50, blue: 0.38, alpha: 1)      // #6B8061
            }
        )

        /// Category badge background — sage green at low opacity.
        static let categoryBadgeBackground = Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.58, green: 0.70, blue: 0.52, alpha: 0.20)
                    : UIColor(red: 0.42, green: 0.50, blue: 0.38, alpha: 0.12)
            }
        )

        /// Tab bar tint — muted sage green for selected tab icon/label.
        static let tabTint = Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.58, green: 0.70, blue: 0.52, alpha: 1)      // #94B385
                    : UIColor(red: 0.38, green: 0.46, blue: 0.34, alpha: 1)      // #617557
            }
        )

        /// Page-level background — subtle warm tint so cards pop.
        static let surface = Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.078, green: 0.075, blue: 0.067, alpha: 1) // #141311
                    : UIColor(red: 0.984, green: 0.973, blue: 0.957, alpha: 1) // #FBF8F4
            }
        )

        /// Elevated surface — grid cells, cards.
        /// Light: near-white with faint warmth. Dark: warm charcoal with clear contrast against surface.
        static let surfaceElevated = Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.173, green: 0.161, blue: 0.149, alpha: 1) // #2C2926
                    : UIColor(red: 0.996, green: 0.992, blue: 0.984, alpha: 1) // #FEFDFB
            }
        )

        /// Card border — subtle edge definition. Dark: light stroke, Light: dark stroke.
        static let cardBorder = Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.08)
                    : UIColor(white: 0.0, alpha: 0.06)
            }
        )

        /// Placeholder backgrounds for missing images.
        static let placeholder = Color(.tertiarySystemFill)

        /// Unselected chip / filter background.
        static let chipBackground = Color(.secondarySystemFill)

        /// Editable input field background — subtle fill to indicate tappable/editable fields.
        static let inputBackground = Color(.tertiarySystemFill)

        /// Destructive action color — stop, delete, discard.
        static let destructive = Color.red
        /// Secondary button color — muted actions.
        static let secondaryButton = Color.gray
    }

    // MARK: - Spacing (4-pt grid)

    enum Spacing {
        static let xxxs: CGFloat = 1
        static let xxs:  CGFloat = 2
        static let xs:   CGFloat = 4
        static let smd:  CGFloat = 6
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 20
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
        static let timerDisplay:  Font = .system(size: 56, weight: .light, design: .monospaced)
    }

    // MARK: - Sizing

    enum Sizing {
        static let thumbnailSmall:        CGFloat = 48
        static let thumbnailForm:         CGFloat = 100
        static let gridImageHeight:       CGFloat = 160
        static let gridCellHeight:        CGFloat = 240
        static let gridMinColumn:         CGFloat = 160
        static let detailImageHeight:     CGFloat = 240
        static let detailPlaceholderHeight: CGFloat = 160

        // Input field widths
        static let inputTime:              CGFloat = 52
        static let inputBuffer:            CGFloat = 60
        static let inputMedium:            CGFloat = 80
        static let inputLarge:             CGFloat = 120

        // Stopwatch
        static let stopwatchButtonWidth:   CGFloat = 130
        static let stopwatchButtonHeight:  CGFloat = 54
    }
}
