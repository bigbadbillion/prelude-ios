import Foundation

struct SaveInsightTool: PreludeAgentTool {
    let name = "saveInsight"

    /// Text supplied by the model via **FoundationModels** tool arguments (scripted path uses default).
    var capturedText: String = "Captured during session"

    init(capturedText: String = "Captured during session") {
        self.capturedText = capturedText
    }

    func execute(_ ctx: ToolExecutionContext) async throws {
        guard let session = ctx.session else { return }
        let insight = Insight(
            text: capturedText,
            emotion: .neutral,
            theme: "Reflection",
            importance: 2,
            session: session
        )
        ctx.modelContext.insert(insight)
    }
}
