import SwiftData
import SwiftUI

@main
struct PreludeApp: App {
    @State private var appState = AppState()

    init() {
        PreludeTTS.prefetchPreferredVoiceAssets()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(PreludeModelContainer.make())
        }
    }
}
