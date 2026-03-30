import SwiftUI

/// Shown while iOS finishes installing a Premium/Enhanced voice (no public download % API—indeterminate UI only).
struct PremiumVoiceWaitSheet: View {
    @Binding var isPresented: Bool
    let palette: PreludePalette
    let isDark: Bool
    /// Called when Premium/Enhanced becomes available or the user opts into standard voice.
    let onContinueToSession: () -> Void

    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preparing natural voice")
                .font(PreludeTypeScale.cardTitle())
                .foregroundStyle(palette.primary)

            Text("Apple is downloading a high-quality voice for the agent. This usually takes a moment.")
                .font(PreludeTypeScale.cardBody())
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView()
                .tint(palette.amber)
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                Button {
                    cancelPoll()
                    isPresented = false
                    onContinueToSession()
                } label: {
                    Text("Continue with standard voice")
                        .font(PreludeTypeScale.cardBody())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                )

                Button("Not now") {
                    cancelPoll()
                    isPresented = false
                }
                .font(PreludeTypeScale.caption())
                .foregroundStyle(palette.tertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.depth.ignoresSafeArea())
        .onAppear { startPolling() }
        .onDisappear { cancelPoll() }
    }

    private func startPolling() {
        cancelPoll()
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                PreludeTTS.prefetchPreferredVoiceAssets()
                if PreludeTTS.isPremiumOrEnhancedVoiceAvailable() {
                    cancelPoll()
                    isPresented = false
                    onContinueToSession()
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func cancelPoll() {
        pollTask?.cancel()
        pollTask = nil
    }
}
