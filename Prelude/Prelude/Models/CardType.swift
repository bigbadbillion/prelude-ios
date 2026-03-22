import Foundation

enum CardType: String, Codable, CaseIterable, Sendable {
    case emotionalState
    case mainConcern
    case keyEmotion
    case whatToSay
    case unresolvedThread
    case therapyGoal
    case patternNote
    /// Affective read on the generated brief (not a diagnosis).
    case emotionalRead
}
