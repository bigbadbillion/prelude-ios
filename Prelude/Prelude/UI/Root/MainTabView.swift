import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var app = appState

        TabView(selection: $app.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tag(PreludeTab.home)
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                HistoryView()
            }
            .tag(PreludeTab.history)
            .tabItem {
                Label("Sessions", systemImage: "clock")
            }

            NavigationStack {
                WeeklyBriefView()
            }
            .tag(PreludeTab.weekly)
            .tabItem {
                Label("This Week", systemImage: "doc.text")
            }

            NavigationStack {
                SettingsView()
            }
            .tag(PreludeTab.settings)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(PreludeColors.amber)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
