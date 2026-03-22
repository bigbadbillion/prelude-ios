import SwiftUI

/// PRD §10.4 — New York (emotional), SF Pro (UI), SF Mono (transcript @ 0.7)
enum PreludeTypography {
    private static let ny = Font.Design.serif

    static func hero(for category: Font.TextStyle = .largeTitle) -> Font {
        .system(category, design: ny).weight(.semibold)
    }

    static func title(for category: Font.TextStyle = .title2) -> Font {
        .system(category, design: ny).weight(.regular)
    }

    static func cardTitle(for category: Font.TextStyle = .title3) -> Font {
        .system(category, design: ny).weight(.semibold)
    }

    static func cardBody(for category: Font.TextStyle = .body) -> Font {
        .system(category, design: ny).weight(.regular)
    }

    static func label(for category: Font.TextStyle = .subheadline) -> Font {
        .system(category, design: .default).weight(.medium)
    }

    static func caption(for category: Font.TextStyle = .caption) -> Font {
        .system(category, design: .default).weight(.regular)
    }

    static func transcript(for category: Font.TextStyle = .subheadline) -> Font {
        .system(category, design: .monospaced).weight(.regular)
    }
}

struct PreludeTypeScale {
    /// Approximate PRD fixed sizes mapped through Dynamic Type via `relativeTo`
    static func hero() -> Font { PreludeTypography.hero(for: .largeTitle) }
    static func title() -> Font { PreludeTypography.title(for: .title2) }
    static func cardTitle() -> Font { PreludeTypography.cardTitle(for: .title3) }
    static func cardBody() -> Font { PreludeTypography.cardBody(for: .body) }
    static func label() -> Font { PreludeTypography.label(for: .footnote) }
    static func caption() -> Font { PreludeTypography.caption(for: .caption2) }
    static func transcript() -> Font { PreludeTypography.transcript(for: .subheadline) }
}
