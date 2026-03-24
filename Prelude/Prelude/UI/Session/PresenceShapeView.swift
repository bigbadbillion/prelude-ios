import SwiftUI
import UIKit

/// PRD prelude-ios §10.5 — presence zone: slow ambient breath, mic + TTS amplitude (smoothed in `VoiceEngine`).
/// Reduce Motion: slower, shallower breath — shape still communicates state.
struct PresenceShapeView: View {
    var voiceState: VoiceState
    var size: CGFloat = 260
    var amplitude: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var breathPeriod: Double { reduceMotion ? 7.8 : 3.95 }

    private func ambientDepth(for state: VoiceState) -> CGFloat {
        let base: CGFloat = reduceMotion ? 0.016 : 0.036
        switch state {
        case .listening: return base
        case .speaking: return base * 0.55
        case .processing: return base * 0.22
        case .idle: return base * 0.75
        case .interrupted: return base * 0.5
        case .paused: return base * 0.35
        case .ended: return base * 0.12
        }
    }

    private func ambientMultiplier(at date: Date, state: VoiceState) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate
        let w = .pi * 2 / breathPeriod
        let phase = CGFloat(sin(t * w))
        return 1 + phase * ambientDepth(for: state)
    }

    private func layerSkewDegrees(at date: Date, index: Int, state: VoiceState) -> Double {
        guard state != .ended else { return 0 }
        let t = date.timeIntervalSinceReferenceDate + Double(index) * 0.55
        let w = .pi * 2 / (breathPeriod * 1.12)
        let amount = reduceMotion ? 1.2 : 2.8
        return sin(t * w) * amount + Double(index) * 2.5
    }

    /// Fill + stroke tint (listening warms toward `preludeActive` with vocal level).
    private var presenceFill: Color {
        switch voiceState {
        case .listening:
            return PreludeColors.calm.mix(with: PreludeColors.active, t: min(1, Double(amplitude) * 0.85))
        case .processing:
            return PreludeColors.processing
        default:
            return PreludeColors.calm
        }
    }

    private func outerStructuralScale(_ state: VoiceState) -> CGFloat {
        switch state {
        case .idle, .listening: 1.06
        case .speaking: 1.14
        case .processing: 0.9
        case .paused: 0.94
        case .ended: 0.84
        case .interrupted: 1.0
        }
    }

    private func midStructuralScale(_ state: VoiceState) -> CGFloat {
        switch state {
        case .idle, .listening: 0.94
        case .speaking: 1.02
        case .processing: 0.76
        case .paused: 0.82
        case .ended: 0.74
        case .interrupted: 0.8
        }
    }

    private func coreStructuralScale(_ state: VoiceState) -> CGFloat {
        switch state {
        case .idle, .listening: 0.72
        case .speaking: 0.86
        case .processing: 0.6
        case .paused: 0.68
        case .ended: 0.62
        case .interrupted: 0.7
        }
    }

    private func ampBoost(for state: VoiceState) -> CGFloat {
        let k: CGFloat =
            switch state {
            case .listening: 0.32
            case .speaking: 0.26
            default: 0.12
            }
        return 1 + min(1, amplitude) * k
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let amb = ambientMultiplier(at: timeline.date, state: voiceState)
            let fill = presenceFill

            ZStack {
                layer(
                    at: timeline.date,
                    index: 0,
                    width: size * 1.12,
                    height: size * 1.06,
                    corner: size * 0.52,
                    baseFill: fill,
                    opacity: 0.14,
                    scale: outerStructuralScale(voiceState) * amb * ampBoost(for: voiceState),
                    extraRotation: -4
                )
                layer(
                    at: timeline.date,
                    index: 1,
                    width: size * 0.88,
                    height: size * 0.92,
                    corner: size * 0.4,
                    baseFill: fill,
                    opacity: 0.11,
                    scale: midStructuralScale(voiceState) * pow(amb, 0.92) * (1 + min(1, amplitude) * 0.16),
                    extraRotation: 5
                )
                layer(
                    at: timeline.date,
                    index: 2,
                    width: size * 0.64,
                    height: size * 0.68,
                    corner: size * 0.3,
                    baseFill: fill,
                    opacity: 0.15,
                    scale: coreStructuralScale(voiceState) * pow(amb, 0.88) * (1 + min(1, amplitude) * 0.11),
                    extraRotation: -2
                )
                Circle()
                    .strokeBorder(fill.opacity(0.28), lineWidth: 1)
                    .frame(width: size + 2, height: size + 2)
            }
            .frame(width: size, height: size)
            .transaction { $0.animation = nil }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.55) : PreludeMotion.gentle, value: voiceState)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.1), value: amplitude)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Presence indicator, currently \(String(describing: voiceState))")
    }

    private func layer(
        at date: Date,
        index: Int,
        width: CGFloat,
        height: CGFloat,
        corner: CGFloat,
        baseFill: Color,
        opacity: Double,
        scale: CGFloat,
        extraRotation: Double
    ) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(baseFill.opacity(opacity))
            .frame(width: width, height: height)
            .scaleEffect(scale)
            .rotationEffect(.degrees(layerSkewDegrees(at: date, index: index, state: voiceState) + extraRotation))
    }
}

private extension Color {
    /// Linear RGB mix (good enough for soft tints between semantic colors).
    func mix(with other: Color, t: Double) -> Color {
        let t = min(1, max(0, t))
        #if os(iOS)
        let from = UIColor(self)
        let to = UIColor(other)
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        guard from.getRed(&fr, green: &fg, blue: &fb, alpha: &fa),
              to.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        else {
            return t < 0.5 ? self : other
        }
        return Color(
            red: Double(fr + (tr - fr) * CGFloat(t)),
            green: Double(fg + (tg - fg) * CGFloat(t)),
            blue: Double(fb + (tb - fb) * CGFloat(t)),
            opacity: Double(fa + (ta - fa) * CGFloat(t))
        )
        #else
        return t < 0.5 ? self : other
        #endif
    }
}
