import XCTest

@testable import Prelude

final class ConversationPhasePolicyTests: XCTestCase {
    func testWarmOpenMovesToOpenFieldOnSubstantiveTurn() {
        var m = SessionTurnMetrics()
        let line = "I've been feeling really overwhelmed at work this week."
        m.recordUserUtterance(line)
        let next = ConversationPhasePolicy.resolvePhase(
            current: .warmOpen,
            userUtterance: line,
            metrics: m,
            savedInsightCount: 0,
            modelAction: .askQuestion,
            sessionElapsedSeconds: 0
        )
        XCTAssertEqual(next, .openField)
    }

    func testReadBackSummaryClampedWhenThinSession() {
        var m = SessionTurnMetrics()
        m.recordUserUtterance("Hi.")
        let next = ConversationPhasePolicy.resolvePhase(
            current: .excavation,
            userUtterance: "Hi.",
            metrics: m,
            savedInsightCount: 0,
            modelAction: .readBackSummary,
            sessionElapsedSeconds: 0
        )
        XCTAssertEqual(next, .excavation)
    }

    func testReadBackAllowedWithInsight() {
        var m = SessionTurnMetrics()
        m.recordUserUtterance("It keeps coming back to shame about how I left things.")
        let next = ConversationPhasePolicy.resolvePhase(
            current: .excavation,
            userUtterance: "It keeps coming back to shame about how I left things.",
            metrics: m,
            savedInsightCount: 1,
            modelAction: .readBackSummary,
            sessionElapsedSeconds: 0
        )
        XCTAssertEqual(next, .readBack)
    }

    func testUserExplicitWrapPhrase() {
        var m = SessionTurnMetrics()
        m.recordUserUtterance("Monday was rough and Tuesday I shut down completely at work.")
        m.recordUserUtterance("Can you recap what we covered before we finish?")
        let line = "Can you recap what we covered before we finish?"
        let next = ConversationPhasePolicy.resolvePhase(
            current: .excavation,
            userUtterance: line,
            metrics: m,
            savedInsightCount: 0,
            modelAction: .respond,
            sessionElapsedSeconds: 0
        )
        XCTAssertEqual(next, .readBack)
    }

    func testExcavationPromotesToReadBackWhenSubstantiveTurnThreshold() {
        var m = SessionTurnMetrics()
        m.recordUserUtterance(
            "I have been feeling really overwhelmed at work all week long and I am not sleeping well at all."
        )
        m.recordUserUtterance("The anxiety spikes whenever my manager schedules a one on one meeting.")
        let line = "I end up ruminating the night before and barely sleep at all anymore."
        m.recordUserUtterance(line)
        let next = ConversationPhasePolicy.resolvePhase(
            current: .excavation,
            userUtterance: line,
            metrics: m,
            savedInsightCount: 0,
            modelAction: .askQuestion,
            sessionElapsedSeconds: 0
        )
        XCTAssertEqual(next, .readBack)
    }

    func testExcavationStaysWhenReadBackAllowedButHostDepthNotMet() {
        var m = SessionTurnMetrics()
        m.recordUserUtterance(
            "Work has been completely overwhelming and I shut down in every meeting this week because I cannot find words when anyone looks at me."
        )
        let line =
            "I cannot tell if I am anxious or exhausted from holding everything together without support from anyone on my team right now."
        m.recordUserUtterance(line)
        let next = ConversationPhasePolicy.resolvePhase(
            current: .excavation,
            userUtterance: line,
            metrics: m,
            savedInsightCount: 0,
            modelAction: .askQuestion,
            sessionElapsedSeconds: 0
        )
        XCTAssertEqual(next, .excavation)
    }

    func testExcavationPromotesToReadBackAfterElapsedSeconds() {
        var m = SessionTurnMetrics()
        let line =
            "It left me ashamed and I do not know how to bring it up with her again without making everything worse."
        m.recordUserUtterance(line)
        let next = ConversationPhasePolicy.resolvePhase(
            current: .excavation,
            userUtterance: line,
            metrics: m,
            savedInsightCount: 1,
            modelAction: .askQuestion,
            sessionElapsedSeconds: 500
        )
        XCTAssertEqual(next, .readBack)
    }

    func testEffectivePhaseForPromptMatchesHostPromotion() {
        var m = SessionTurnMetrics()
        m.recordUserUtterance(
            "I have been feeling really overwhelmed at work all week long and I am not sleeping well at all."
        )
        m.recordUserUtterance("The anxiety spikes whenever my manager schedules a one on one meeting.")
        let line = "I end up ruminating the night before and barely sleep at all anymore."
        m.recordUserUtterance(line)
        let eff = ConversationPhasePolicy.effectivePhaseForPrompt(
            storedPhase: .excavation,
            userUtterance: line,
            metricsIncludingLatestUserTurn: m,
            savedInsightCount: 0,
            sessionElapsedSeconds: 0
        )
        let resolved = ConversationPhasePolicy.resolvePhase(
            current: .excavation,
            userUtterance: line,
            metrics: m,
            savedInsightCount: 0,
            modelAction: .respond,
            sessionElapsedSeconds: 0
        )
        XCTAssertEqual(eff, .readBack)
        XCTAssertEqual(resolved, .readBack)
    }
}
