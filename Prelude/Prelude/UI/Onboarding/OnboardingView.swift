import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var scheme
    var onComplete: () -> Void

    @State private var appeared = false

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }

    var body: some View {
        ZStack {
            palette.depth.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 24) {
                        PresenceShapeView(voiceState: .idle, size: 160, amplitude: 0)
                        Text("Prelude")
                            .font(PreludeTypeScale.title())
                            .foregroundStyle(palette.primary)
                            .tracking(2)
                    }
                    .padding(.top, 48)
                    .opacity(appeared ? 1 : 0)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("A space to prepare.")
                            .font(PreludeTypeScale.title())
                            .foregroundStyle(palette.primary)
                        Text("Prelude helps you arrive at therapy ready — by guiding a short reflection before your session, so you carry what matters most into the room.")
                            .font(PreludeTypeScale.cardBody())
                            .foregroundStyle(palette.secondary)
                        Text("Everything stays on your device. Your words, your insights — private by design.")
                            .font(PreludeTypeScale.cardBody())
                            .foregroundStyle(palette.secondary)
                    }
                    .padding(.horizontal, 8)
                    .opacity(appeared ? 1 : 0)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.tertiary)
                        Text(CrisisDetection.disclaimer)
                            .font(PreludeTypeScale.caption())
                            .foregroundStyle(palette.tertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(palette.raised.opacity(0.65))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(palette.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 4)
                    .opacity(appeared ? 1 : 0)

                    Button {
                        PreludeHaptics.sessionBegin()
                        onComplete()
                    } label: {
                        Text("I understand")
                            .font(PreludeTypeScale.cardTitle())
                            .foregroundStyle(palette.amber)
                    }
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0)
                    .accessibilityLabel("I understand, continue to home")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.65).delay(0.12)) {
                appeared = true
            }
        }
    }
}
