import SwiftUI

struct BriefCardView: View {
    let type: CardType
    let text: String
    var isUserWords: Bool = false

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
