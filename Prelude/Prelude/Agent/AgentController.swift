import Combine
import Foundation
import SwiftData

/// Owns the agent loop lifecycle (PRD §5–6). Uses **LanguageModelSession** on iOS 26+ when Apple Intelligence is available; scripted lines only when the on-device model is not used (e.g. Simulator).
@MainActor
final class AgentController: ObservableObject {
    @Published private(set) var currentPhase: ConversationPhase = .warmOpen

    /// Scripted lines matching Expo `AGENT_SCRIPT` when the on-device model is not used.
    private static let script: [String] = VoiceEngineScript.lines

    private var scriptIndex = 1
    private var modelTurnCount = 0

    /// Type-erased **LanguageModelSession** when Foundation Models is linked (`#if canImport` callers cast).
    var foundationSessionStorage: Any?

    /// Whether `foundationSessionStorage` was created with tool adapters (vs text-only session).
    var foundationSessionUsesTools: Bool?

    var toolContextBox: PreludeToolContextBox?

    /// `true` when we should **not** use the scripted conversation fallback (physical device + model ready, etc.).
    private var useScriptedFallback: Bool {
        !PreludeModelAvailability.shouldAttemptFoundationModels
    }

    /// Spoken when the model path is required but `respond` fails or returns an unmapped decision (device testing).
    static let liveAgentFailureLine =
        "I'm having trouble with the on-device model. Please try again in a moment — say a few words and I'll listen."

    /// Spoken when the model returns an empty `spokenResponse` while live mode is on.
    static let liveAgentEmptyResponseLine =
        "I didn't get words to say back. Could you try that once more, in a short phrase?"

    /// Opening line if `runOpening` fails but we still avoid the fixed Expo script on device.
    static let liveAgentOpeningFallback =
        "Whenever you're ready, I'm listening. How are you coming into today?"

    func resetForNewSession() {
        scriptIndex = 1
        modelTurnCount = 0
        currentPhase = .warmOpen
        foundationSessionStorage = nil
        foundationSessionUsesTools = nil
        toolContextBox = nil
    }

    func attachToolContext(modelContext: ModelContext, session: Session) {
        toolContextBox = PreludeToolContextBox(modelContext: modelContext, session: session)
    }

    /// First TTS line: **LanguageModelSession** on device when eligible; otherwise scripted line 0.
    func generateOpeningLine(modelContext: ModelContext, session: Session) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), PreludeModelAvailability.shouldAttemptFoundationModels, let box = toolContextBox {
            return await PreludeFoundationModels.runOpening(
                agent: self,
                modelContext: modelContext,
                session: session,
                box: box
            )
        }
        #endif
        return nil
    }

    /// Voice layer entry: structured line + whether to end the session after this agent speech (e.g. model `endSession`).
    func respondToUserTurn(
        userUtterance: String,
        modelContext: ModelContext,
        session: Session
    ) async -> (line: String?, endSessionAfter: Bool) {
        if let decision = await streamDecision(userUtterance: userUtterance, modelContext: modelContext, session: session) {
            let end = decision.action == .endSession
            let trimmed = decision.spokenResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if useScriptedFallback, let line = await nextLineAfterUserTurn() {
                    return (line, false)
                }
                return (Self.liveAgentEmptyResponseLine, false)
            }
            return (trimmed, end)
        }

        if useScriptedFallback {
            if let line = await nextLineAfterUserTurn() {
                return (line, false)
            }
            return (nil, false)
        }

        // Device + model should run: never substitute the mock script; surface failure so you can see it in-session.
        return (Self.liveAgentFailureLine, false)
    }

    /// Returns next agent line after a user turn, or `nil` when the session should end (Expo `onUserTurnComplete` semantics).
    func nextLineAfterUserTurn() async -> String? {
        if scriptIndex >= Self.script.count {
            return nil
        }
        let line = Self.script[scriptIndex]
        scriptIndex += 1
        advancePhaseHeuristic()
        return line
    }

    private func advancePhaseHeuristic() {
        switch scriptIndex {
        case ..<2: currentPhase = .warmOpen
        case 2 ..< 4: currentPhase = .openField
        case 4 ..< 5: currentPhase = .excavation
        case 5: currentPhase = .readBack
        default: currentPhase = .closing
        }
    }

    /// True when per-turn prompts should steer toward an audible **session recap** (readBack or the turn right before phase flips to readBack).
    var shouldSteerTowardSessionRecapInPrompt: Bool {
        if currentPhase == .readBack { return true }
        if currentPhase == .excavation, modelTurnCount >= 5 { return true }
        return false
    }

    /// Maps free-model actions into **ConversationPhase** for SwiftData + UI (coarse; model also receives phase in prompt).
    func applyModelPhaseTransition(for action: AgentAction) {
        modelTurnCount += 1
        switch action {
        case .readBackSummary:
            currentPhase = .readBack
        case .endSession:
            currentPhase = .closing
        default:
            switch modelTurnCount {
            case ..<2: currentPhase = .warmOpen
            case 2 ..< 4: currentPhase = .openField
            case 4 ..< 6: currentPhase = .excavation
            case 6 ..< 8: currentPhase = .readBack
            default: currentPhase = .closing
            }
        }
    }

    func streamDecision(userUtterance: String, modelContext: ModelContext, session: Session) async -> AgentDecision? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard let box = toolContextBox else { return nil }
            return await PreludeFoundationModels.runTurn(
                agent: self,
                userUtterance: userUtterance,
                modelContext: modelContext,
                session: session,
                box: box
            )
        }
        #endif
        return nil
    }
}

/// Shared script for `VoiceEngine` / `AgentController` (single source).
enum VoiceEngineScript {
    static let lines: [String] = [
        "Take a moment to settle in. There's no hurry here. When you're ready — how are you coming into today?",
        "I hear that. When you say things have felt heavy — is there a particular moment this week that sits with you most?",
        "It sounds like there's a real weight in that. What emotion is underneath it, if you had to name one?",
        "Here's what I'm taking from our time: you've been carrying something heavy, there's real uncertainty about what comes next, and underneath it there's still a thread of hope that things could shift. Does that feel close — and is there anything else you want to add before we wrap, or does that feel like enough for today?",
        "Thank you for sharing so honestly. I'll pull together your brief now — it's yours to take into your session.",
    ]
}
