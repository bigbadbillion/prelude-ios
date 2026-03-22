import SwiftUI

/// PRD §10.5 presence zone — organic layered form; VoiceOver label on container.
struct PresenceShapeView: View {
    var voiceState: VoiceState
    var size: CGFloat = 260
    var amplitude: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stateColor: Color {
        voiceState == .processing ? PreludeColors.processing : PreludeColors.calm
    }

    private var outerScale: CGFloat {
        let base: CGFloat =
            switch voiceState {
            case .idle, .listening: 1.08
            case .speaking: 1.18
            case .processing: 0.88
            case .paused: 0.94
            case .ended: 0.82
            case .interrupted: 1.0
            }
        let ampBoost = 1 + CGFloat(amplitude) * 0.28
        return base * ampBoost
    }

    var body: some View {
        ZStack {
            layer(width: size * 1.1, height: size * 1.1, corner: size * 0.55, opacity: 0.15, scale: outerScale)
            layer(width: size * 0.85, height: size * 0.9, corner: size * 0.42, opacity: 0.10, scale: midScale)
            layer(width: size * 0.62, height: size * 0.66, corner: size * 0.32, opacity: 0.15, scale: coreScale)
            Circle()
                .strokeBorder(
                    (voiceState == .listening ? PreludeColors.calm : stateColor).opacity(0.25),
                    lineWidth: 1
                )
                .frame(width: size + 2, height: size + 2)
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : PreludeMotion.gentle, value: voiceState)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: amplitude)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Presence indicator, currently \(String(describing: voiceState))")
    }

    private var midScale: CGFloat {
        let base: CGFloat =
            switch voiceState {
            case .idle, .listening: 0.95
            case .speaking: 1.04
            case .processing: 0.74
            default: 0.78
            }
        return base * (1 + CGFloat(amplitude) * 0.17)
    }

    private var coreScale: CGFloat {
        let base: CGFloat =
            switch voiceState {
            case .idle, .listening: 0.72
            case .speaking: 0.88
            case .processing: 0.58
            default: 0.70
            }
        return base * (1 + CGFloat(amplitude) * 0.1)
    }

    private func layer(width: CGFloat, height: CGFloat, corner: CGFloat, opacity: Double, scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(stateColor.opacity(opacity))
            .frame(width: width, height: height)
            .scaleEffect(reduceMotion ? 1 : scale)
    }
}
