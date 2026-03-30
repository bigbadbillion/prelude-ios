import SwiftData
import SwiftUI

struct WeeklyBriefView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeeklyBrief.generatedAt, order: .reverse) private var briefs: [WeeklyBrief]

    @State private var isRegenerating = false

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }
    private var weekly: WeeklyBrief? { briefs.first }

    private var isDark: Bool { scheme == .dark }

    private static let weekOfFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMMd")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        ZStack {
            palette.depth.ignoresSafeArea()
            ScrollView {
                if let w = weekly {
                    weeklyScrollContent(w)
                } else {
                    Text("Your weekly brief will appear after you complete sessions.")
                        .font(PreludeTypeScale.cardBody())
                        .foregroundStyle(palette.secondary)
                        .padding(24)
                }
            }
        }
        .navigationTitle("This Week")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func weeklyScrollContent(_ w: WeeklyBrief) -> some View {
        let arcSessions = SessionStore.sessionsForWeeklyEmotionalArc(sessionIds: w.sessionIds, in: modelContext)
        let paragraphs = w.summary
            .split(separator: "\n\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        VStack(alignment: .leading, spacing: 14) {
            Text("Week of \(Self.weekOfFormatter.string(from: w.weekStart))")
                .font(PreludeTypeScale.label())
                .foregroundStyle(palette.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if arcSessions.count >= 2 {
                emotionalArcCard(sessions: arcSessions)
            }

            // Main narrative card
            VStack(alignment: .leading, spacing: 20) {
                Text("This week.")
                    .font(PreludeTypeScale.title())
                    .foregroundStyle(palette.primary)

                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, p in
                    Text(p)
                        .font(PreludeTypeScale.cardBody())
                        .foregroundStyle(index == 0 ? palette.primary : palette.secondary)
                        .lineSpacing(4)
                        .padding(.top, index == 0 ? 0 : 16)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Expo `mainCard`: solid `colors.surface` + `colors.border` — not Liquid Glass.
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(palette.border, lineWidth: 1)
                    }
            }

            // Recurring themes
            if !w.themes.isEmpty {
                themesSection(themes: w.themes)
            }

            // Worth bringing up
            if let s = w.suggestions.first, !s.isEmpty {
                suggestionCard(text: s)
            }

            // Regenerate
            regenerateButton()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    private func themesSection(themes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECURRING THEMES")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.tertiary)
                .tracking(1.3)

            // Expo `weekly.tsx`: `tagRow` flexWrap + gap 8 (not a multi-column grid).
            ThemeTagFlowLayout(spacing: 8) {
                ForEach(Array(themes.enumerated()), id: \.offset) { _, theme in
                    Text(theme)
                        // `styles.tagText`: Inter 500 13
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.amber)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(palette.amber.opacity(isDark ? 0.12 : 0.10))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(palette.amber.opacity(0.25), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.top, 4)
    }

    private func suggestionCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.amber)
                Text("Worth bringing up")
                    .font(PreludeTypeScale.label())
                    .foregroundStyle(palette.amber)
                    .tracking(0.2)
            }

            Text(text)
                .font(PreludeTypeScale.cardBody())
                .foregroundStyle(palette.primary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.amber.opacity(isDark ? 0.08 : 0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.amber.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func regenerateButton() -> some View {
        Button {
            guard !isRegenerating else { return }
            isRegenerating = true
            Task {
                await BriefStore.refreshWeeklyBriefIfNeeded(modelContext: modelContext)
                try? modelContext.save()
                await MainActor.run {
                    isRegenerating = false
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.tertiary)
                Text("Regenerate")
                    .font(PreludeTypeScale.caption())
                    .foregroundStyle(palette.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .disabled(isRegenerating)
        .accessibilityLabel("Regenerate weekly brief")
    }

    private func emotionalArcCard(sessions: [Session]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("EMOTIONAL ARC")
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .tracking(1.3)
                    .foregroundStyle(isDark ? PreludeColors.tertiaryDark : PreludeColors.tertiaryLight)
                Spacer(minLength: 8)
                Text("across sessions")
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .tracking(0.3)
                    .foregroundStyle(isDark ? PreludeColors.tertiaryDark : PreludeColors.tertiaryLight)
            }
            .padding(.horizontal, 14)

            EmotionalArcChartView(sessions: sessions)
                .padding(.horizontal, 4)

            HStack {
                Text("heavier")
                Spacer()
                Text("lighter")
            }
            .font(.system(size: 8, weight: .regular, design: .default))
            .tracking(0.4)
            .foregroundStyle((isDark ? PreludeColors.tertiaryDark : PreludeColors.tertiaryLight).opacity(0.6))
            .padding(.horizontal, 24)
            .padding(.top, 2)
        }
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PreludeColors.weeklyChartCardFill(for: scheme))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                }
        }
    }
}

// MARK: - Theme tags (RN `flexWrap` parity)

/// Horizontal flow with wrap, matching React Native `flexDirection: 'row'` + `flexWrap: 'wrap'` + `gap`.
private struct ThemeTagFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, maxWidth: proposal.width ?? .infinity).0
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (_, frames) = layout(subviews: subviews, maxWidth: bounds.width)
        for (index, subview) in subviews.enumerated() {
            let origin = CGPoint(x: bounds.minX + frames[index].minX, y: bounds.minY + frames[index].minY)
            subview.place(at: origin, proposal: ProposedViewSize(frames[index].size))
        }
    }

    private func layout(subviews: Subviews, maxWidth: CGFloat) -> (CGSize, [CGRect]) {
        var frames: [CGRect] = []
        var rowX: CGFloat = 0
        var rowY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowX + size.width > maxWidth, rowX > 0 {
                widestRow = max(widestRow, rowX - spacing)
                rowX = 0
                rowY += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: rowX, y: rowY, width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            rowX += size.width + spacing
        }
        widestRow = max(widestRow, rowX == 0 ? 0 : rowX - spacing)

        let totalHeight = rowY + rowHeight
        let width = maxWidth.isFinite ? min(widestRow, maxWidth) : widestRow
        return (CGSize(width: width, height: totalHeight), frames)
    }
}
