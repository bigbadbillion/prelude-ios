import Foundation

enum UserSettings {
    private static let userNameKey = "prelude.userName"
    private static let disclaimerKey = "prelude.disclaimer"

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
    }
}
