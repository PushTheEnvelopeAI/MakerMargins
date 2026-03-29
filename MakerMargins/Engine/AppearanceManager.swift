// AppearanceManager.swift
// MakerMargins
//
// Manages user's preferred appearance (System / Light / Dark).
// Injected once at the app root and accessed via @Environment(\.appearanceManager).

import SwiftUI
import Observation

// MARK: - AppearanceSetting

enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }
}

// MARK: - AppearanceManager

@MainActor
@Observable
final class AppearanceManager {

    /// Explicitly nonisolated so the type can be instantiated from any context
    /// (e.g. EnvironmentKey.defaultValue). All stored properties have inline
    /// defaults, so the body is empty.
    nonisolated init() {}

    var setting: AppearanceSetting = {
        if let raw = UserDefaults.standard.string(forKey: "appearanceSetting"),
           let value = AppearanceSetting(rawValue: raw) {
            return value
        }
        return .system
    }() {
        didSet {
            if oldValue != setting {
                UserDefaults.standard.set(setting.rawValue, forKey: "appearanceSetting")
            }
        }
    }

    /// Returns nil for system (no override), or a specific scheme.
    var resolvedColorScheme: ColorScheme? {
        switch setting {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Environment

private struct AppearanceManagerKey: EnvironmentKey {
    static let defaultValue = AppearanceManager()
}

extension EnvironmentValues {
    var appearanceManager: AppearanceManager {
        get { self[AppearanceManagerKey.self] }
        set { self[AppearanceManagerKey.self] = newValue }
    }
}
