import Foundation

struct TagEmotionTool: PreludeAgentTool {
    let name = "tagEmotion"

    private let parsedEmotion: EmotionLabel?

    /// Scripted / default path.
    init(fallback: EmotionLabel = .hopeful) {
        self.parsedEmotion = fallback
    }

    /// On-device model supplies a **EmotionLabel** raw string. Invalid labels **do not** overwrite (avoids silent `neutral`).
    init(parsingRawLabel raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.parsedEmotion = EmotionLabel(rawValue: trimmed)
    }

    func execute(_ ctx: ToolExecutionContext) async throws {
        guard let session = ctx.session, let e = parsedEmotion else { return }
        session.dominantEmotion = e
    }
}
