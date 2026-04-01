import SwiftUI

struct BriefCardView: View {
    let type: CardType
    let text: String
    var isUserWords: Bool = false
    /// When non-empty, renders one panel with numbered lines instead of a single `text` block.
    var numberedLines: [String] = []

    @Environment(\.colorScheme) private var scheme

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }

    private var config: (icon: String, label: String) {
        switch type {
        case .emotionalState: return ("waveform.path.ecg", "HOW I SHOWED UP")
        case .mainConcern: return ("cloud", "WEIGHING ON ME")
        case .keyEmotion: return ("heart", "KEY EMOTION")
        case .whatToSay: return ("bubble.left", "WHAT I NEED TO SAY")
        case .unresolvedThread: return ("arrow.triangle.branch", "UNRESOLVED THREAD")
        case .therapyGoal: return ("location.north.circle", "WHAT I HOPE FOR TODAY")
        case .patternNote: return ("arrow.triangle.2.circlepath", "A PATTERN WORTH NOTING")
        case .emotionalRead: return ("sparkles", "HOW THIS BRIEF READS")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: config.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.amber)
                Text(config.label)
                    .font(PreludeTypeScale.caption())
                    .foregroundStyle(palette.tertiary)
            }
            if isUserWords {
                Text(text)
                    .font(PreludeTypeScale.cardBody())
                    .foregroundStyle(palette.primary)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(palette.amber.opacity(0.85))
                            .frame(width: 3)
                    }
            } else if !numberedLines.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(numberedLines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1).")
                                .font(PreludeTypeScale.cardBody())
                                .foregroundStyle(palette.tertiary)
                                .frame(minWidth: 22, alignment: .trailing)
                            Text(line)
                                .font(PreludeTypeScale.cardBody())
                                .foregroundStyle(palette.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Text(text)
                    .font(PreludeTypeScale.cardBody())
                    .foregroundStyle(palette.primary)
            }
        }
        .padding(22)
        .preludeGlassCard()
        .padding(.bottom, 12)
    }
}
