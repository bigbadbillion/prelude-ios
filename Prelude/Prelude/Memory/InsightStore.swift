import Foundation
import SwiftData

/// Insight queries for brief synthesis and agent tools (PRD Phase 4).
enum InsightStore {
    @MainActor
    static func insights(for sessionId: UUID, in modelContext: ModelContext) -> [Insight] {
        let sid = sessionId
        var fd = FetchDescriptor<Insight>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        let all = (try? modelContext.fetch(fd)) ?? []
        return all.filter { $0.session?.id == sid }
    }

    /// Compact lines for model prompts and `getPastInsights` tool output.
    @MainActor
    static func recentInsightsSummary(
        modelContext: ModelContext,
        excludingSessionId: UUID?,
        query: String,
        limit: Int = 10
    ) -> String {
        var desc = FetchDescriptor<Insight>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        desc.fetchLimit = limit * 3
        let insights = (try? modelContext.fetch(desc)) ?? []
        let filtered = insights.filter { $0.session?.id != excludingSessionId }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let narrowed: [Insight]
        if q.isEmpty {
            narrowed = filtered
        } else {
            narrowed = filtered.filter {
                $0.text.lowercased().contains(q) || $0.theme.lowercased().contains(q)
            }
        }
        let top = Array(narrowed.prefix(limit))
        guard !top.isEmpty else {
            return "No prior insights found in recent sessions."
        }
        return top.enumerated().map { i, ins in
            "\(i + 1). (\(ins.emotion.rawValue)) \(ins.theme): \(ins.text)"
        }.joined(separator: "\n")
    }
}
