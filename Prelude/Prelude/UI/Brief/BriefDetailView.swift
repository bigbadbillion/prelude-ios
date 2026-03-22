import SwiftData
import SwiftUI

struct BriefDetailView: View {
    let sessionId: UUID

    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context

    @State private var session: Session?

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }

    var body: some View {
        Group {
            if let session, let brief = session.brief {
                content(session: session, brief: brief)
            } else {
                Text("Brief not found")
                    .font(PreludeTypeScale.cardBody())
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(palette.depth.ignoresSafeArea())
        .task { await load() }
        .onAppear { PreludeHaptics.briefReady() }
    }

    @ViewBuilder
    private func content(session: Session, brief: SessionBrief) -> some View {
        let cards = buildCards(from: brief)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Session Brief")
                    .font(PreludeTypeScale.label())
                    .foregroundStyle(palette.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                Text(sessionDate(session.startedAt))
                    .font(PreludeTypeScale.label())
                    .foregroundStyle(palette.secondary)
                    .padding(.bottom, 20)

                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    BriefCardView(type: card.type, text: card.text, isUserWords: card.isUserWords)
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
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func sessionDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }

    private struct CardItem {
        let type: CardType
        let text: String
        var isUserWords: Bool = false
    }

    private func buildCards(from brief: SessionBrief) -> [CardItem] {
        var cards: [CardItem] = [
            CardItem(type: .emotionalState, text: brief.emotionalState),
        ]
        if let t = brief.themes.first {
            cards.append(CardItem(type: .mainConcern, text: t, isUserWords: false))
        }
        if let f = brief.focusItems.first {
            cards.append(CardItem(type: .keyEmotion, text: f))
        }
        cards.append(CardItem(type: .whatToSay, text: brief.patientWords, isUserWords: true))
        if brief.focusItems.count > 1 {
            cards.append(CardItem(type: .unresolvedThread, text: brief.focusItems[1]))
        }
        for i in 2 ..< brief.focusItems.count {
            cards.append(CardItem(type: .therapyGoal, text: brief.focusItems[i]))
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
        cards.map { "\($0.type.rawValue.uppercased())\n\($0.text)" }.joined(separator: "\n\n")
    }

    @MainActor
    private func load() async {
        let sid = sessionId
        let fd = FetchDescriptor<Session>(predicate: #Predicate { $0.id == sid })
        session = try? context.fetch(fd).first
    }
}
