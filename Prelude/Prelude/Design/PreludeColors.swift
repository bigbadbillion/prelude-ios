import SwiftUI

/// PRD §10.3 + [artifacts/prelude/constants/colors.ts](artifacts/prelude/constants/colors.ts)
enum PreludeColors {
    static let depthDark = Color(red: 0.059, green: 0.051, blue: 0.039)
    static let depthLight = Color(red: 0.980, green: 0.969, blue: 0.949)
    static let surfaceDark = Color(red: 0.110, green: 0.094, blue: 0.075)
    static let surfaceLight = Color(red: 0.941, green: 0.922, blue: 0.890)
    static let raisedDark = Color(red: 0.145, green: 0.125, blue: 0.094)
    static let raisedLight = Color(red: 0.910, green: 0.882, blue: 0.839)

    static let primaryDark = Color(red: 0.961, green: 0.941, blue: 0.910)
    static let primaryLight = Color(red: 0.102, green: 0.086, blue: 0.071)
    static let secondaryDark = Color(red: 0.620, green: 0.580, blue: 0.522)
    static let secondaryLight = Color(red: 0.420, green: 0.376, blue: 0.341)
    static let tertiaryDark = Color(red: 0.361, green: 0.329, blue: 0.282)
    static let tertiaryLight = Color(red: 0.620, green: 0.580, blue: 0.522)

    static let amber = Color(red: 0.784, green: 0.529, blue: 0.227)
    static let sage = Color(red: 0.478, green: 0.620, blue: 0.494)
    static let calm = Color(red: 0.290, green: 0.486, blue: 0.557)
    static let active = amber
    static let processing = Color(red: 0.420, green: 0.369, blue: 0.306)
    static let overlay = Color(red: 0.059, green: 0.051, blue: 0.039).opacity(0.6)

    static func border(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.08)
    }
}

struct PreludePalette {
    var depth: Color
    var surface: Color
    var raised: Color
    var primary: Color
    var secondary: Color
    var tertiary: Color
    var border: Color
    let amber: Color = PreludeColors.amber
    let sage: Color = PreludeColors.sage
    let calm: Color = PreludeColors.calm
    let active: Color = PreludeColors.active
    let processing: Color = PreludeColors.processing
    let overlay: Color = PreludeColors.overlay

    static func palette(for scheme: ColorScheme) -> PreludePalette {
        let dark = scheme == .dark
        return PreludePalette(
            depth: dark ? PreludeColors.depthDark : PreludeColors.depthLight,
            surface: dark ? PreludeColors.surfaceDark : PreludeColors.surfaceLight,
            raised: dark ? PreludeColors.raisedDark : PreludeColors.raisedLight,
            primary: dark ? PreludeColors.primaryDark : PreludeColors.primaryLight,
            secondary: dark ? PreludeColors.secondaryDark : PreludeColors.secondaryLight,
            tertiary: dark ? PreludeColors.tertiaryDark : PreludeColors.tertiaryLight,
            border: PreludeColors.border(for: scheme)
        )
    }
}

extension Color {
    /// PRD §8 emotion mapping (AppContext emotionColors)
    static func preludeEmotion(_ label: EmotionLabel) -> Color {
        switch label {
        case .anxious: return Color(red: 0.710, green: 0.514, blue: 0.353)
        case .sad: return Color(red: 0.420, green: 0.549, blue: 0.682)
        case .angry: return Color(red: 0.682, green: 0.420, blue: 0.420)
        case .confused: return Color(red: 0.549, green: 0.482, blue: 0.682)
        case .hopeful: return PreludeColors.sage
        case .overwhelmed: return Color(red: 0.682, green: 0.549, blue: 0.420)
        case .frustrated: return Color(red: 0.769, green: 0.451, blue: 0.294)
        case .neutral: return Color(red: 0.620, green: 0.580, blue: 0.522)
        case .grieving: return Color(red: 0.482, green: 0.549, blue: 0.682)
        }
    }
}
