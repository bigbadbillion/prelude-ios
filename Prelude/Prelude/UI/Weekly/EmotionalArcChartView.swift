import SwiftData
import SwiftUI

// MARK: - Geometry (artifacts/prelude/app/(tabs)/weekly.tsx)

enum EmotionalArcChartGeometry {
    /// Higher = lighter / more positive on the chart (maps to lower Y).
    static func weight(for emotion: EmotionLabel) -> CGFloat {
        switch emotion {
        case .excited: return 0.95
        case .happy: return 0.91
        case .hopeful: return 0.88
        case .calm: return 0.52
        case .reflective: return 0.58
        case .confused: return 0.38
        case .frustrated: return 0.28
        case .sad: return 0.22
        case .anxious: return 0.18
        case .grieving: return 0.12
        case .overwhelmed: return 0.10
        case .angry: return 0.10
        }
    }

    static func catmullRomPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }
        if points.count == 1 {
            path.move(to: points[0])
            return path
        }
        path.move(to: points[0])
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        return path
    }

    static func areaPath(line: Path, first: CGPoint, last: CGPoint, baselineY: CGFloat) -> Path {
        var p = line
        p.addLine(to: CGPoint(x: last.x, y: baselineY))
        p.addLine(to: CGPoint(x: first.x, y: baselineY))
        p.closeSubpath()
        return p
    }
}

// MARK: - View

/// Emotional arc over completed sessions. Stroke and area gradient use the **latest session’s tagged** `dominantEmotion` only — same as Expo `weekly.tsx` (`dominantColor` / `emotionColors`, not brief inference). Point labels use `EmotionLabel.resolved(for:)` so dots can reflect brief tone when the tag is missing or baseline `.calm`.
struct EmotionalArcChartView: View {
    @Environment(\.colorScheme) private var scheme

    let sessions: [Session]

    private var isDark: Bool { scheme == .dark }

    /// Expo `weekly.tsx`: `dominantColor` from `pts_sessions[last].dominantEmotion` via `emotionColors`, else `PreludeColors.calm`. Using `EmotionLabel.resolved` for stroke would change the line (e.g. calm grey-taupe vs anxious brown).
    private static func lineAndFillTintColor(for sessions: [Session]) -> Color {
        guard let last = sessions.last(where: { $0.completedAt != nil }) else {
            return PreludeColors.calm
        }
        guard let tagged = last.dominantEmotion else {
            return PreludeColors.calm
        }
        return Color.preludeEmotion(tagged)
    }

    private static let chartDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMd")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        GeometryReader { geo in
            let layout = computeLayout(width: geo.size.width)
            let lineTint = Self.lineAndFillTintColor(for: sessions)
            let linePath = EmotionalArcChartGeometry.catmullRomPath(points: layout.cgPoints)
            let areaPath = EmotionalArcChartGeometry.areaPath(
                line: linePath,
                first: layout.cgPoints[0],
                last: layout.cgPoints[layout.cgPoints.count - 1],
                baselineY: layout.baselineY
            )

            ZStack(alignment: .topLeading) {
                // Expo SVG: linearGradient on the filled area (top → bottom of the shaded region).
                // A masked rectangle avoids SwiftUI path-fill gradient quirks that read as flat grey.
                let gradH = max(1, layout.baselineY - layout.curveMinY)
                let gradMidY = layout.curveMinY + gradH / 2
                LinearGradient(
                    colors: [
                        lineTint.opacity(isDark ? 0.18 : 0.14),
                        lineTint.opacity(0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: gradH)
                .position(x: geo.size.width / 2, y: gradMidY)
                .mask(areaPath)

                // Expo: stroke = emotion hex, Path opacity 0.7 / 0.65
                linePath.stroke(
                    lineTint.opacity(isDark ? 0.7 : 0.65),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )

                ForEach(layout.entries) { entry in
                    let pt = entry.point
                    let color = Color.preludeEmotion(entry.emotion)
                    ZStack {
                        Circle()
                            .fill(layout.surfaceFill)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(color.opacity(0.9), lineWidth: 1.5))
                        Circle()
                            .fill(color.opacity(0.95))
                            .frame(width: 5, height: 5)
                    }
                    .position(pt)

                    Text(entry.emotion.rawValue)
                        .font(.system(size: 7, weight: .regular, design: .default))
                        .foregroundStyle(color.opacity(0.75))
                        .position(x: pt.x, y: pt.y - 10)

                    Text(Self.chartDateFormatter.string(from: entry.date))
                        .font(.system(size: 8, weight: .regular, design: .default))
                        .foregroundStyle(PreludeColors.weeklyChartDateLabel(for: scheme))
                        .position(x: pt.x, y: layout.coreHeight + 16)
                }
            }
            .compositingGroup()
            .frame(width: geo.size.width, height: layout.totalHeight, alignment: .topLeading)
        }
        .frame(height: 100 + 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard sessions.count >= 2 else { return "" }
        let parts = sessions.compactMap { s -> String? in
            guard let d = s.completedAt else { return nil }
            let e = EmotionLabel.resolved(for: s)
            return "\(Self.chartDateFormatter.string(from: d)), \(e.rawValue)"
        }
        return "Emotional arc across sessions: " + parts.joined(separator: "; ")
    }

    private struct LayoutEntry: Identifiable {
        let id: UUID
        let point: CGPoint
        let emotion: EmotionLabel
        let date: Date
    }

    private struct ComputedLayout {
        let entries: [LayoutEntry]
        let cgPoints: [CGPoint]
        let coreHeight: CGFloat
        let padY: CGFloat
        let baselineY: CGFloat
        let curveMinY: CGFloat
        let surfaceFill: Color
        let totalHeight: CGFloat
    }

    private func computeLayout(width: CGFloat) -> ComputedLayout {
        let padX: CGFloat = 20
        let padY: CGFloat = 12
        let coreHeight: CGFloat = 100
        let bottomBand: CGFloat = 28
        let chartW = max(1, width - padX * 2)
        let chartInnerH = coreHeight - padY * 2
        let plottedSessions = sessions.compactMap { s -> (Session, Date)? in
            guard let c = s.completedAt else { return nil }
            return (s, c)
        }
        let m = plottedSessions.count

        // Expo circle fill: `PreludeColors.surface.dark` / `.light` (not material).
        let surfaceFill = scheme == .dark ? PreludeColors.surfaceDark : PreludeColors.surfaceLight
        let baselineY = coreHeight - padY + 4

        var entries: [LayoutEntry] = []
        for (i, pair) in plottedSessions.enumerated() {
            let (s, completed) = pair
            let emotion = EmotionLabel.resolved(for: s)
            let w = EmotionalArcChartGeometry.weight(for: emotion)
            let x: CGFloat
            if m == 1 {
                x = padX + chartW / 2
            } else {
                x = padX + (CGFloat(i) / CGFloat(m - 1)) * chartW
            }
            let y = padY + chartInnerH - w * chartInnerH
            entries.append(LayoutEntry(id: s.id, point: CGPoint(x: x, y: y), emotion: emotion, date: completed))
        }

        let cgPoints = entries.map(\.point)
        let curveMinY = entries.map(\.point.y).min() ?? padY

        return ComputedLayout(
            entries: entries,
            cgPoints: cgPoints,
            coreHeight: coreHeight,
            padY: padY,
            baselineY: baselineY,
            curveMinY: curveMinY,
            surfaceFill: surfaceFill,
            totalHeight: coreHeight + bottomBand
        )
    }
}
