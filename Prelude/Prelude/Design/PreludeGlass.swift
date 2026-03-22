import SwiftUI

/// PRD §10.6 — Liquid Glass / materials only where allowed (cards overlay, sheets, history panel, nav-on-scroll).
/// Do **not** use on presence zone, main background, or plain body containers.
struct PreludeGlassCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(PreludePalette.palette(for: scheme).border, lineWidth: 1)
                    }
            }
    }
}

struct PreludeGlassSheetBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(.thinMaterial)
    }
}

extension View {
    func preludeGlassCard() -> some View { modifier(PreludeGlassCard()) }
    func preludeGlassSheet() -> some View { modifier(PreludeGlassSheetBackground()) }
}
