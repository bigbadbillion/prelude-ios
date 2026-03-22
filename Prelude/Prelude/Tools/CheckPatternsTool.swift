import Foundation

/// Computes cross-session pattern context; persists nothing until a **FoundationModels** adapter is added.
struct CheckPatternsTool: PreludeAgentTool {
    let name = "checkPatterns"

    func execute(_ ctx: ToolExecutionContext) async throws {
        await MainActor.run {
            let sessions = SessionStore.completedSessionsChronological(in: ctx.modelContext)
            _ = PatternDetector.summaryLines(from: sessions, focusSessionId: ctx.session?.id)
        }
    }
}
