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
            modelAction: .askQuestion
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
            modelAction: .readBackSummary
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
            modelAction: .readBackSummary
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
            modelAction: .respond
        )
        XCTAssertEqual(next, .readBack)
    }
}
