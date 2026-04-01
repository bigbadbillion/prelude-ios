import SwiftData
import SwiftUI

struct BriefDetailView: View {
    let sessionId: UUID

    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var session: Session?
    @State private var showDeleteConfirm = false
    @State private var deleteFailed = false

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }

    var body: some View {
        Group {
            if let session, let brief = session.brief {
                briefScrollView(session: session, brief: brief)
            } else {
                Text("Brief not found")
                    .font(PreludeTypeScale.cardBody())
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(palette.depth.ignoresSafeArea())
        .task(id: sessionId) { await load() }
        .onAppear { PreludeHaptics.briefReady() }
        .confirmationDialog(
            "Delete this brief?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteBriefTapped()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the session from your history, including the brief and related notes. Weekly summaries will drop this session from their chart if it was listed.")
        }
        .alert("Couldn’t delete", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try again. If the problem continues, restart the app.")
        }
    }

    @ViewBuilder
    private func briefScrollView(session: Session, brief: SessionBrief) -> some View {
        let cards = buildCards(from: brief)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Session Brief")
                    .font(PreludeTypeScale.label())
                    .foregroundStyle(palette.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                briefDateAndEmotionRow(session: session)
                    .padding(.bottom, 20)

                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    BriefCardView(
                        type: card.type,
                        text: card.text,
                        isUserWords: card.isUserWords,
                        numberedLines: card.numberedLines ?? []
                    )
                    .transition(.opacity.combined(with: .offset(y: 12)))
                }
                .animation(PreludeMotion.reveal, value: cards.count)

                ShareLink(item: shareText(cards: cards)) {
                    Text("Take this to your session")
                        .font(PreludeTypeScale.cardBody())
                        .foregroundStyle(palette.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                .accessibilityLabel("Take this to your session — shares brief as text")

                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("Delete this brief")
                        .font(PreludeTypeScale.label())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.red.opacity(0.9))
                .accessibilityHint("Removes this session and its brief from your device")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func deleteBriefTapped() {
        do {
            try MemoryStore.deleteSessionAndPruneWeekly(sessionId: sessionId, modelContext: context)
            showDeleteConfirm = false
            // Drop SwiftData references before dismiss so no render pass touches deleted objects.
            session = nil
            if appState.sessionBriefToPresent == sessionId {
                appState.sessionBriefToPresent = nil
            }
            DispatchQueue.main.async {
                dismiss()
            }
        } catch {
            deleteFailed = true
        }
    }

    private func sessionDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }

    private func briefDateAndEmotionRow(session: Session) -> some View {
        let label = EmotionLabel.resolved(for: session)
        let title = label.rawValue.localizedCapitalized
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(sessionDate(session.startedAt))
                .font(PreludeTypeScale.label())
                .foregroundStyle(palette.secondary)
            Text("·")
                .font(PreludeTypeScale.label())
                .foregroundStyle(palette.tertiary)
            Circle()
                .fill(Color.preludeEmotion(label))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(title)
                .font(PreludeTypeScale.label())
                .foregroundStyle(Color.preludeEmotion(label))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sessionDate(session.startedAt)), dominant emotion \(title)")
    }

    private struct CardItem {
        let type: CardType
        let text: String
        var isUserWords: Bool = false
        /// When set, `BriefCardView` shows one panel with a numbered list (weighing / hope cards).
        var numberedLines: [String]? = nil
    }

    private func buildCards(from brief: SessionBrief) -> [CardItem] {
        var cards: [CardItem] = [
            CardItem(type: .emotionalState, text: brief.emotionalState),
        ]
        let weighingLines = brief.themes.prefix(3).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !weighingLines.isEmpty {
            cards.append(
                CardItem(type: .mainConcern, text: "", numberedLines: weighingLines)
            )
        }
        if let f = brief.focusItems.first {
            cards.append(CardItem(type: .keyEmotion, text: f))
        }
        cards.append(CardItem(type: .whatToSay, text: brief.patientWords, isUserWords: true))
        if brief.focusItems.count > 1 {
            cards.append(CardItem(type: .unresolvedThread, text: brief.focusItems[1]))
        }
        var hopeLines: [String] = []
        if brief.focusItems.count > 2 {
            let g1 = brief.focusItems[2].trimmingCharacters(in: .whitespacesAndNewlines)
            if !g1.isEmpty { hopeLines.append(g1) }
        }
        if brief.focusItems.count > 3 {
            let g2 = brief.focusItems[3].trimmingCharacters(in: .whitespacesAndNewlines)
            if !g2.isEmpty { hopeLines.append(g2) }
        }
        if !hopeLines.isEmpty {
            cards.append(CardItem(type: .therapyGoal, text: "", numberedLines: hopeLines))
        }
        let affective = brief.affectiveAnalysis.trimmingCharacters(in: .whitespacesAndNewlines)
        if !affective.isEmpty {
            cards.append(CardItem(type: .emotionalRead, text: affective))
        }
        if let p = brief.patternNote {
            cards.append(CardItem(type: .patternNote, text: p))
        }
        return cards
    }

    private func shareText(cards: [CardItem]) -> String {
        cards.map { card in
            let header = card.type.rawValue.uppercased()
            if let lines = card.numberedLines, !lines.isEmpty {
                let body = lines.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                return "\(header)\n\(body)"
            }
            return "\(header)\n\(card.text)"
        }.joined(separator: "\n\n")
    }

    @MainActor
    private func load() async {
        let sid = sessionId
        let fd = FetchDescriptor<Session>(predicate: #Predicate { $0.id == sid })
        session = try? context.fetch(fd).first
    }
}
