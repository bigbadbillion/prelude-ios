import UIKit

/// PRD §10.8 — maps key moments to haptics (UIKit generators for broad compatibility).
enum PreludeHaptics {
    static func sessionBegin() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func briefReady() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func sessionEnd() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func errorTap() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func destructiveActionCommitted() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
