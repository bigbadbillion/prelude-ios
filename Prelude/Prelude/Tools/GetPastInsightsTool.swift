import Foundation
import SwiftData

struct GetPastInsightsTool: PreludeAgentTool {
    let name = "getPastInsights"

    func execute(_ ctx: ToolExecutionContext) async throws {
        // Read-only query path; model tools use `recentInsightsSummary` for string output.
    }

    /// Compact summary for **FoundationModels** tool return value (main-actor SwiftData read).
    @MainActor
    static func recentInsightsSummary(
        modelContext: ModelContext,
        excludingSessionId: UUID?,
        query: String,
        limit: Int = 10
    ) -> String {
        InsightStore.recentInsightsSummary(
            modelContext: modelContext,
            excludingSessionId: excludingSessionId,
            query: query,
            limit: limit
        )
    }
}
