// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return L("settings.theme.system")
        case .light: return L("settings.theme.light")
        case .dark: return L("settings.theme.dark")
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

class ThemeManager {
    static let shared = ThemeManager()

    private let themeKey = "settings.theme"

    var currentTheme: AppTheme {
        get {
            if let saved = UserDefaults.standard.string(forKey: themeKey),
               let theme = AppTheme(rawValue: saved) {
                return theme
            }
            return .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: themeKey)
            applyTheme(newValue)
        }
    }

    private init() {
        applyTheme(currentTheme)
    }

    func applyTheme(_ theme: AppTheme) {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.appearance = theme.appearance
            }
        }
    }
}
