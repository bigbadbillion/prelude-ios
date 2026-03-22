import Foundation

/// Mirrors PRD §5 `@Generable` shape; use **FoundationModels** `@Generable` when building with iOS 26 SDK.
struct AgentDecision: Codable, Sendable {
    var action: AgentAction
    var spokenResponse: String
    var reasoning: String
}

enum AgentAction: String, Codable, Sendable {
    case respond
    case askQuestion
    case saveInsight
    case reflectBack
    case readBackSummary
    case endSession

    /// Maps model output that doesn’t exactly match `rawValue` (common with on-device models).
    static func lenient(from key: String) -> AgentAction {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let exact = AgentAction(rawValue: k) { return exact }
        switch k {
        case "answer", "reply", "speak", "say", "continue", "ack", "acknowledge", "greet", "greeting", "hello", "welcome":
            return .respond
        case "question", "ask", "ask_question", "askquestion":
            return .askQuestion
        case "insight", "remember", "note", "save", "save_insight", "saveinsight":
            return .saveInsight
        case "reflect", "mirror", "reflect_back":
            return .reflectBack
        case "readback", "read_back", "readbacksummary", "summary", "summarize":
            return .readBackSummary
        case "end", "close", "finish", "goodbye", "end_session", "endsession":
            return .endSession
        default:
            return .respond
        }
    }
}
