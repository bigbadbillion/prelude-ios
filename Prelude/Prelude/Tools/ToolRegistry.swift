import Foundation

enum ToolRegistry {
    static func allTools() -> [any PreludeAgentTool] {
        [
            SaveInsightTool(),
            TagEmotionTool(),
            GenerateCardTool(),
            GetPastInsightsTool(),
            CheckPatternsTool(),
            SummarizeSessionTool(),
            EndSessionTool(),
        ]
    }
}
