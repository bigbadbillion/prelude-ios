import Foundation

struct SummarizeSessionTool: PreludeAgentTool {
    let name = "summarizeSession"

    func execute(_ ctx: ToolExecutionContext) async throws {
        guard let session = ctx.session else { return }
        await BriefStore.synthesizeAndAttachSessionBrief(modelContext: ctx.modelContext, sessionId: session.id)
        await MainActor.run { try? ctx.modelContext.save() }
    }
}
