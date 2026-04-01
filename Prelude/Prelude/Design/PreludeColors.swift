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

    // MARK: - Expo `weekly.tsx` (artifacts/prelude/app/(tabs)/weekly.tsx)

    /// Chart card `backgroundColor` (not `mainCard` surface).
    static func weeklyChartCardFill(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.025)
            : Color(red: 26 / 255, green: 22 / 255, blue: 18 / 255).opacity(0.03)
    }

    /// Date labels under points: `PreludeColors.secondary.dark/light` at opacity `0.7` in Expo SVG.
    static func weeklyChartDateLabel(for scheme: ColorScheme) -> Color {
        let base = scheme == .dark ? secondaryDark : secondaryLight
        return base.opacity(0.7)
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
    /// Warm-instrument palette (`colors.ts` / Expo). Each label is a distinct hue for small markers and the weekly arc.
    static func preludeEmotion(_ label: EmotionLabel) -> Color {
        switch label {
        case .anxious: return Color(red: 0.710, green: 0.478, blue: 0.380)
        case .sad: return Color(red: 0.420, green: 0.549, blue: 0.682)
        case .angry: return Color(red: 0.682, green: 0.380, blue: 0.400)
        case .confused: return Color(red: 0.549, green: 0.451, blue: 0.682)
        case .hopeful: return PreludeColors.sage
        case .happy: return Color(red: 0.380, green: 0.718, blue: 0.520)
        case .excited: return Color(red: 0.898, green: 0.549, blue: 0.310)
        case .overwhelmed: return Color(red: 0.569, green: 0.482, blue: 0.369)
        case .frustrated: return Color(red: 0.780, green: 0.431, blue: 0.275)
        case .calm: return PreludeColors.calm
        case .reflective: return Color(red: 0.451, green: 0.529, blue: 0.620)
        case .grieving: return Color(red: 0.502, green: 0.439, blue: 0.620)
        }
    }
}
