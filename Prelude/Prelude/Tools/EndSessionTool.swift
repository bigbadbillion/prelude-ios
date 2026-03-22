import Foundation

struct EndSessionTool: PreludeAgentTool {
    let name = "endSession"

    func execute(_ ctx: ToolExecutionContext) async throws {
        guard let session = ctx.session else { return }
        session.completedAt = .now
        session.phase = .closing
    }
}
