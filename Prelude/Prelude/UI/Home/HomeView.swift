import Foundation
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    @State private var showAvailabilityAlert = false
    @State private var showPremiumVoiceWait = false

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }
    private var isDark: Bool { scheme == .dark }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    /// Most recently **completed** session (not merely the latest row, which may be in progress).
    private var completedSessionsNewestFirst: [Session] {
        sessions.filter { $0.completedAt != nil }
    }

    private var lastSessionLine: String {
        guard let s = completedSessionsNewestFirst.first, let t = s.brief?.themes.first else {
            return "Ready when you are."
        }
        return "Last time: \(t)"
    }

    private var lastCompletedSession: Session? {
        completedSessionsNewestFirst.first
    }

    /// Streak note (3+ consecutive) or recurring-theme hint from `PatternDetector`.
    private var homeEmergingPatternText: String? {
        let newestFirst = completedSessionsNewestFirst
        guard let newest = newestFirst.first else { return nil }
        let ascending = Array(newestFirst.reversed())
        if let streak = PatternDetector.consecutiveStreakPatternNote(
            completedSessionsAscending: ascending,
            focusSessionId: newest.id
        ) {
            return streak
        }
        return PatternDetector.recurringThemeHintAmongRecent(completedNewestFirst: newestFirst)
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

                    if let s = lastCompletedSession {
                        lastSessionCard(session: s)
                        if let pattern = homeEmergingPatternText {
                            emergingPatternCard(text: pattern)
                        }
                        recentCheckInsSection()
                    }
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
        .sheet(isPresented: $showPremiumVoiceWait) {
            PremiumVoiceWaitSheet(
                isPresented: $showPremiumVoiceWait,
                palette: palette,
                isDark: isDark,
                onContinueToSession: {
                    appState.showSession = true
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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
            let hasCompletedBefore = !completedSessionsNewestFirst.isEmpty
            if PreludeTTS.shouldWaitForPremiumVoiceBeforeFirstSession(userHasCompletedSession: hasCompletedBefore) {
                showPremiumVoiceWait = true
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

    private func formatLastSessionLabel(for completedAt: Date) -> String {
        let cal = Calendar.current
        let startCompleted = cal.startOfDay(for: completedAt)
        let startNow = cal.startOfDay(for: Date())
        let daysDiff = cal.dateComponents([.day], from: startCompleted, to: startNow).day ?? 0
        if daysDiff == 0 { return "TODAY" }
        if daysDiff == 1 { return "YESTERDAY" }
        return "\(daysDiff) DAYS AGO"
    }

    private func lastSessionCard(session: Session) -> some View {
        let minutes = max(1, session.durationSeconds / 60)
        let themesLine = session.brief?.themes.joined(separator: "  ·  ") ?? "Reflection session"
        let tone = session.brief?.affectiveAnalysis.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Text(formatLastSessionLabel(for: session.completedAt!))
                    .font(PreludeTypeScale.label())
                    .foregroundStyle(palette.tertiary)
                    .textCase(.uppercase)

                Spacer(minLength: 0)

                Text("\(minutes) min")
                    .font(PreludeTypeScale.caption())
                    .foregroundStyle(palette.sage)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(palette.sage.opacity(isDark ? 0.12 : 0.14))
                    .clipShape(Capsule())
            }

            Text(themesLine)
                .font(PreludeTypeScale.cardBody())
                .foregroundStyle(palette.secondary)
                .lineLimit(2)

            if let tone, !tone.isEmpty {
                Text("Tone: \(tone)")
                    .font(PreludeTypeScale.caption())
                    .foregroundStyle(palette.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.035) : Color.black.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func emergingPatternCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EMERGING PATTERN")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.tertiary)
                .tracking(1.2)
            Text(text)
                .font(PreludeTypeScale.cardBody())
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.035) : Color.black.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func recentCheckInsSection() -> some View {
        let rows = Array(completedSessionsNewestFirst.prefix(2))
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("RECENT CHECK-INS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.tertiary)
                    .tracking(1.2)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(rows, id: \.id) { session in
                        recentCheckInRow(session: session)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isDark ? Color.white.opacity(0.035) : Color.black.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func recentCheckInRow(session: Session) -> some View {
        let (title, emotionForColor): (String, EmotionLabel?) = {
            if let e = session.dominantEmotion {
                return (e.rawValue.capitalized, e)
            }
            let line = session.brief?.emotionalState.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !line.isEmpty {
                return (line, nil)
            }
            return ("Not tagged", .calm)
        }()

        return HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(Color.preludeEmotion(emotionForColor ?? .calm))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PreludeTypeScale.cardBody())
                    .foregroundStyle(palette.primary)
                    .lineLimit(emotionForColor == nil && title.count > 40 ? 2 : 1)
                Text(shortDateLabel(for: session.completedAt!))
                    .font(PreludeTypeScale.caption())
                    .foregroundStyle(palette.tertiary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func shortDateLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
