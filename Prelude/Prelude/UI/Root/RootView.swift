import SwiftData
import SwiftUI

struct BriefPresentation: Identifiable, Hashable {
    let id: UUID
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var showDisclaimerFlow = !UserSettings.hasSeenDisclaimer

    var body: some View {
        @Bindable var app = appState

        ZStack {
            MainTabView()
                .fullScreenCover(isPresented: $app.showSession) {
                    SessionView()
                }
                .sheet(item: Binding(
                    get: { app.sessionBriefToPresent.map(BriefPresentation.init(id:)) },
                    set: { app.sessionBriefToPresent = $0?.id }
                )) { item in
                    NavigationStack {
                        BriefDetailView(sessionId: item.id)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Close") {
                                        app.sessionBriefToPresent = nil
                                    }
                                }
                            }
                    }
                }
        }
        .fullScreenCover(isPresented: $showDisclaimerFlow) {
            OnboardingView {
                UserSettings.hasSeenDisclaimer = true
                showDisclaimerFlow = false
            }
        }
        .onChange(of: app.localDataResetCount) { _, _ in
            showDisclaimerFlow = !UserSettings.hasSeenDisclaimer
        }
        .onAppear {
            app.refreshAvailability()
            Task {
                await BriefStore.refreshWeeklyBriefIfNeeded(modelContext: context)
                try? context.save()
            }
        }
    }
}
