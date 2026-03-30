import Foundation

extension EmotionLabel {
    /// Dominant emotion for brief header and weekly arc: uses `Session.dominantEmotion` when set; otherwise scans brief prose (`firstMentioned`); defaults to `.calm`. If tagged `.calm` but brief names another label, prefers the inferred label.
    static func resolved(for session: Session) -> EmotionLabel {
        let briefCorpus = [
            session.brief?.emotionalState,
            session.brief?.affectiveAnalysis,
            session.brief?.themes.joined(separator: " "),
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
        let inferred = EmotionLabel.firstMentioned(in: briefCorpus)
        guard let tagged = session.dominantEmotion else {
            return inferred ?? .calm
        }
        if tagged == .calm, let inferred, inferred != .calm {
            return inferred
        }
        return tagged
    }
}
