import Foundation

enum ConversationPhase: String, Codable, Sendable {
    case warmOpen
    case openField
    case excavation
    case readBack
    case closing
}
