import Foundation

struct TagEmotionTool: PreludeAgentTool {
    let name = "tagEmotion"

    private var parsedEmotion: EmotionLabel?

    /// Scripted / default path.
    init(fallback: EmotionLabel = .hopeful) {
        self.parsedEmotion = fallback
    }

    /// On-device model supplies a **EmotionLabel** raw string.
    init(parsingRawLabel raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.parsedEmotion = EmotionLabel(rawValue: trimmed) ?? .neutral
    }

    func execute(_ ctx: ToolExecutionContext) async throws {
        guard let session = ctx.session else { return }
        session.dominantEmotion = parsedEmotion ?? .hopeful
    }
}
