import SwiftUI

/// Soft ambient shapes — PRD warm instrument; not chatbot “orb” cliché.
struct AmbientBlobsView: View {
    let palette: PreludePalette
    let isDark: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                AmbientBlob(
                    size: 420,
                    x: w * 0.72,
                    y: 180,
                    opacity: isDark ? 0.055 : 0.07,
                    rotateDuration: 28,
                    rotateOffset: 15,
                    breathDuration: 5,
                    color: palette.amber,
                    radius: 0.48
                )
                AmbientBlob(
                    size: 320,
                    x: w * 0.18,
                    y: 380,
                    opacity: isDark ? 0.04 : 0.055,
                    rotateDuration: 34,
                    rotateOffset: 200,
                    breathDuration: 6.5,
                    color: palette.sage,
                    radius: 0.44
                )
                AmbientBlob(
                    size: 260,
                    x: w * 0.65,
                    y: 580,
                    opacity: isDark ? 0.03 : 0.045,
                    rotateDuration: 22,
                    rotateOffset: 90,
                    breathDuration: 4.8,
                    color: palette.amber,
                    radius: 0.5
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AmbientBlob: View {
    var size: CGFloat
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
    var rotateDuration: Double
    var rotateOffset: Double
    var breathDuration: Double
    var color: Color
    var radius: CGFloat

    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1

    var body: some View {
        Ellipse()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size * 0.9)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .position(x: x, y: y)
            .onAppear {
                rotation = rotateOffset
                withAnimation(.linear(duration: rotateDuration).repeatForever(autoreverses: false)) {
                    rotation = rotateOffset + 360
                }
                withAnimation(.easeInOut(duration: breathDuration).repeatForever(autoreverses: true)) {
                    scale = 1.05
                }
            }
            .accessibilityHidden(true)
    }
}
