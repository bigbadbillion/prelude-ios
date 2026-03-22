import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    @State private var showAvailabilityAlert = false

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }
    private var isDark: Bool { scheme == .dark }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var lastSessionLine: String {
        guard let s = sessions.first, let t = s.brief?.themes.first else {
            return "Ready when you are."
        }
        return "Last time: \(t)"
    }

    var body: some View {
        @Bindable var app = appState

        ZStack {
            palette.depth.ignoresSafeArea()
            AmbientBlobsView(palette: palette, isDark: isDark)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(greetingText)
                                .font(PreludeTypeScale.hero())
                                .foregroundStyle(palette.primary)
                            Text(lastSessionLine)
                                .font(PreludeTypeScale.caption())
                                .foregroundStyle(palette.secondary)
                        }
                        .padding(.top, 8)

                        beginButton
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(app.availability.title, isPresented: $showAvailabilityAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(app.availability.message)
        }
    }

    private var greetingText: String {
        let name = UserSettings.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = name.split(separator: " ").first.map(String.init)
        if let first, !first.isEmpty {
            return "\(greeting),\n\(first)."
        }
        return "\(greeting)."
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Prelude")
                    .font(PreludeTypeScale.title())
                    .foregroundStyle(palette.primary)
                Rectangle()
                    .fill(palette.amber.opacity(isDark ? 0.35 : 0.45))
                    .frame(width: 1, height: 18)
                Text("Therapy prep")
                    .font(PreludeTypeScale.label())
                    .foregroundStyle(palette.amber)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isDark ? Color.white.opacity(0.055) : Color.black.opacity(0.07))
                .frame(height: 1)
        }
    }

    private var beginButton: some View {
        Button {
            PreludeHaptics.sessionBegin()
            if !appState.canStartSession() {
                showAvailabilityAlert = true
                return
            }
            if !UserSettings.hasSeenDisclaimer {
                // Root handles first-launch flow; if user cleared defaults, show alert
                return
            }
            appState.showSession = true
        } label: {
            HStack(spacing: 14) {
                Text("Begin Reflection")
                    .font(PreludeTypeScale.cardTitle())
                    .foregroundStyle(palette.amber)
                ZStack {
                    Circle()
                        .strokeBorder(palette.amber.opacity(isDark ? 0.3 : 0.35), lineWidth: 1)
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.amber)
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 22)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.amber.opacity(isDark ? 0.11 : 0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(palette.amber.opacity(isDark ? 0.38 : 0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Begin Reflection")
    }
}
