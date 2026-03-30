import Foundation

struct SaveInsightTool: PreludeAgentTool {
    let name = "saveInsight"

    /// Text supplied by the model via **FoundationModels** tool arguments (scripted path uses default).
    var capturedText: String = "Captured during session"
    var emotion: EmotionLabel = .calm

    init(capturedText: String = "Captured during session", emotion: EmotionLabel = .calm) {
        self.capturedText = capturedText
        self.emotion = emotion
    }

    func execute(_ ctx: ToolExecutionContext) async throws {
        guard let session = ctx.session else { return }
        let insight = Insight(
            text: capturedText,
            emotion: emotion,
            theme: "Reflection",
            importance: 2,
            session: session
        )
        ctx.modelContext.insert(insight)
    }
}
