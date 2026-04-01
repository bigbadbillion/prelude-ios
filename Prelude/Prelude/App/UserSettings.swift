import Foundation
import SwiftUI

enum PreludeColorSchemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// `nil` follows the system appearance.
    var resolvedColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum UserSettings {
    private static let userNameKey = "prelude.userName"
    private static let disclaimerKey = "prelude.disclaimer"
    static let colorSchemeStorageKey = "prelude.colorScheme"

    static var userName: String {
        get { UserDefaults.standard.string(forKey: userNameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: userNameKey) }
    }

    static var hasSeenDisclaimer: Bool {
        get { UserDefaults.standard.bool(forKey: disclaimerKey) }
        set { UserDefaults.standard.set(newValue, forKey: disclaimerKey) }
    }

    /// Removes Prelude keys from `UserDefaults` (used by “Clear all data”).
    static func clearAllSavedKeys() {
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: disclaimerKey)
        UserDefaults.standard.removeObject(forKey: colorSchemeStorageKey)
    }
}
