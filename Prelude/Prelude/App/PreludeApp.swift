import SwiftData
import SwiftUI

@main
struct PreludeApp: App {
    @State private var appState = AppState()
    @AppStorage(UserSettings.colorSchemeStorageKey) private var colorSchemeRaw = PreludeColorSchemePreference.system.rawValue

    init() {
        PreludeTTS.prefetchPreferredVoiceAssets()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(PreludeModelContainer.make())
                .preferredColorScheme(
                    (PreludeColorSchemePreference(rawValue: colorSchemeRaw) ?? .system).resolvedColorScheme
                )
        }
    }
}
