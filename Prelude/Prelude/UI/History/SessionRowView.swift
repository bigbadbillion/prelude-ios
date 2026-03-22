import SwiftData
import SwiftUI

struct SessionRowView: View {
    let session: Session

    @Environment(\.colorScheme) private var scheme

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(Color.preludeEmotion(session.dominantEmotion ?? .neutral))
                .frame(width: 10, height: 10)
                .padding(.top, 5)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(rowDate)
                    .font(PreludeTypeScale.label())
                    .foregroundStyle(palette.secondary)
                Text(themeLine)
                    .font(PreludeTypeScale.cardBody())
                    .foregroundStyle(palette.primary)
                    .lineLimit(2)
                Text(durationLine)
                    .font(PreludeTypeScale.caption())
                    .foregroundStyle(palette.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rowDate), \(durationLine), \(themeLine)")
    }

    private var rowDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: session.startedAt)
    }

    private var themeLine: String {
        session.brief?.themes.first ?? "Reflection session"
    }

    private var durationLine: String {
        let m = max(1, session.durationSeconds / 60)
        return "\(m) min"
    }
}
