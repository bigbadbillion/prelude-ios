import Foundation

// MARK: - User signals (deterministic; English phrases for therapy-prep context)

/// Lightweight parsing — no ML. Keeps behavior predictable for TestFlight.
enum UserUtteranceSignals {
    private static let wrapPhrases: [String] = [
        "wrap up", "wrap this up", "recap", "summarize", "summary", "that's enough",
        "that is enough", "enough for today", "before we finish", "before we go",
        "what we covered", "what i shared", "ready to close", "move toward closing",
        "pull it together", "how does that sound",
    ]

    private static let endPhrases: [String] = [
        "goodbye", "bye", "i have to go", "got to go", "stop the session", "end session",
        "end the session", "that's all", "im done", "i'm done", "we're done",
    ]

    private static let greetingOnly: [String] = [
        "hi", "hey", "hello", "hi there", "hey there", "morning", "afternoon", "evening",
    ]

    struct Parsed: Sendable {
        var wantsReadBackOrWrap: Bool
        var wantsEndSession: Bool
        var isMinimalGreetingOnly: Bool
    }

    static func parse(_ raw: String) -> Parsed {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = t.lowercased()

        let wantsEnd = endPhrases.contains { lower.contains($0) }
        let wantsWrap = wrapPhrases.contains { lower.contains($0) }

        let words = t.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }
        let wordCount = words.count
        let greetingMatch = greetingOnly.contains { g in
            lower == g || lower.hasPrefix(g + " ") || lower == g + "."
        }
        let minimalGreeting =
            !wantsWrap && !wantsEnd
            && wordCount <= 4
            && t.count <= 28
            && (greetingMatch || (wordCount <= 2 && !lower.contains(",")))

        return Parsed(
            wantsReadBackOrWrap: wantsWrap,
            wantsEndSession: wantsEnd,
            isMinimalGreetingOnly: minimalGreeting
        )
    }
}

// MARK: - Session metrics (user-grounded, not agent turn count)

struct SessionTurnMetrics: Sendable {
    var substantiveUserTurns: Int = 0
    var cumulativeUserWords: Int = 0

    mutating func recordUserUtterance(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let words = trimmed.split { $0.isWhitespace || $0.isNewline }
        cumulativeUserWords += words.count

        let sig = UserUtteranceSignals.parse(trimmed)
        if sig.isMinimalGreetingOnly { return }

        let substantive = words.count >= 5 || trimmed.count >= 36
        if substantive {
            substantiveUserTurns += 1
        }
    }
}

// MARK: - Policy

enum ConversationPhasePolicy {
    /// Minimum material before a **model-requested** read-back is allowed (prevents hollow summaries).
    private static let minWordsForModelReadBack = 40
    private static let minSubstantiveTurnsForModelReadBack = 2

    /// User explicitly asked to wrap — still need *something* to summarize.
    private static let minWordsWhenUserRequestsWrap = 18

    static func readBackAllowed(
        metrics: SessionTurnMetrics,
        savedInsightCount: Int,
        signals: UserUtteranceSignals.Parsed
    ) -> Bool {
        if savedInsightCount >= 1, metrics.substantiveUserTurns >= 1 { return true }
        if signals.wantsReadBackOrWrap, metrics.cumulativeUserWords >= minWordsWhenUserRequestsWrap { return true }
        if metrics.substantiveUserTurns >= minSubstantiveTurnsForModelReadBack,
           metrics.cumulativeUserWords >= minWordsForModelReadBack { return true }
        return false
    }

    static func closingAllowed(
        current: ConversationPhase,
        signals: UserUtteranceSignals.Parsed,
        modelRequestedEnd: Bool
    ) -> Bool {
        if modelRequestedEnd {
            if current == .readBack || current == .closing { return true }
            if current == .excavation || current == .openField { return signals.wantsEndSession }
            return false
        }
        return signals.wantsEndSession && (current == .readBack || current == .excavation || current == .openField)
    }

    /// Single source of truth for phase after the agent has produced a decision for this user turn.
    static func resolvePhase(
        current: ConversationPhase,
        userUtterance: String,
        metrics: SessionTurnMetrics,
        savedInsightCount: Int,
        modelAction: AgentAction
    ) -> ConversationPhase {
        let signals = UserUtteranceSignals.parse(userUtterance)
        let rbOK = readBackAllowed(metrics: metrics, savedInsightCount: savedInsightCount, signals: signals)

        if closingAllowed(current: current, signals: signals, modelRequestedEnd: modelAction == .endSession) {
            return .closing
        }

        if modelAction == .readBackSummary, rbOK {
            return .readBack
        }

        if signals.wantsReadBackOrWrap, rbOK {
            return .readBack
        }

        switch current {
        case .warmOpen:
            if signals.isMinimalGreetingOnly { return .warmOpen }
            return .openField

        case .openField:
            if shouldEnterExcavation(metrics: metrics, savedInsightCount: savedInsightCount) {
                return .excavation
            }
            return .openField

        case .excavation:
            return .excavation

        case .readBack:
            return .readBack

        case .closing:
            return .closing
        }
    }

    private static func shouldEnterExcavation(metrics: SessionTurnMetrics, savedInsightCount: Int) -> Bool {
        if savedInsightCount >= 1 { return true }
        if metrics.substantiveUserTurns >= 2 { return true }
        if metrics.cumulativeUserWords >= 90 { return true }
        return false
    }
}
