#if canImport(FoundationModels)
import Foundation
import FoundationModels
import os
import SwiftData

private enum PreludeFMLog {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Prelude", category: "FoundationModels")
}

// MARK: - @Generable decision (PRD §5)
// `action` is a string (not a @Generable enum) to satisfy FoundationModels `Generable` synthesis.

@Generable
struct GenerableAgentDecision {
    @Guide(
        description: """
            One of: respond, askQuestion, saveInsight, reflectBack, readBackSummary, endSession. \
            Prefer **askQuestion** when you are mainly offering a reflective follow-up; use saveInsight / \
            tagEmotion / generateCard / getPastInsights via tools when appropriate. \
            Use **readBackSummary** only when the user has shared enough real material to summarize (the host enforces this).
            """
    )
    var action: String

    @Guide(
        description: """
            Text for TTS: warm, calm, brief. **Default:** end with **one** open reflective question after \
            the user shares (unless phase is closing, crisis, or they only gave a minimal greeting). \
            **Vary** how you open: sometimes name the tension directly, sometimes a short empathic line without \
            “it sounds like” / “that sounds like” (avoid that formula most turns — it feels robotic). \
            Pattern: brief connect + one question that deepens reflection.
            """
    )
    var spokenResponse: String

    @Guide(description: "Internal reasoning — not spoken aloud")
    var reasoning: String
}

extension AgentDecision {
    /// Maps model output using **AgentAction.lenient** so varied `action` strings still produce a speakable turn.
    @available(iOS 26.0, *)
    init?(generable g: GenerableAgentDecision) {
        let spoken = g.spokenResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return nil }
        let key = g.action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.init(action: AgentAction.lenient(from: key), spokenResponse: spoken, reasoning: g.reasoning)
    }
}

/// Simpler schema for the first utterance (fewer required fields → fewer generation failures).
@Generable
struct GenerableOpeningUtterance {
    @Guide(
        description: """
            Warm, brief invitation for TTS; one or two sentences. **End with an open question** \
            (e.g. how they are arriving today). If the prompt gives a preferred name, use it once. \
            If it gives last-session context, nod to it briefly then shift to what’s here now — don’t lecture.
            """
    )
    var spokenResponse: String
}

// MARK: - Tool adapters (delegate to PreludeAgentTool + SwiftData)

enum PreludeFoundationToolFactory {
    @available(iOS 26.0, *)
    static func makeTools(box: PreludeToolContextBox) -> [any Tool] {
        [
            SaveInsightFMTool(box: box),
            TagEmotionFMTool(box: box),
            GenerateCardFMTool(box: box),
            GetPastInsightsFMTool(box: box),
            EndSessionFMTool(box: box),
        ]
    }
}

// Apple recommends limiting concurrent tools in-prompt; these five cover the live session loop.

@MainActor
enum PreludeFMToolRunner {
    static func saveInsight(box: PreludeToolContextBox, text: String, emotionLabel: String) async throws -> String {
        let ctx = ToolExecutionContext(modelContext: box.modelContext, session: box.session)
        let emotion = resolvedEmotionForInsight(text: text, rawLabel: emotionLabel)
        try await SaveInsightTool(capturedText: text, emotion: emotion).execute(ctx)
        try? box.modelContext.save()
        return "Insight saved for the brief."
    }

    /// Parses model label; falls back to substring match in insight text (same idea as brief inference).
    private static func resolvedEmotionForInsight(text: String, rawLabel: String) -> EmotionLabel {
        let t = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let e = EmotionLabel.parseCanonicalKey(t) { return e }
        return EmotionLabel.firstMentioned(in: text) ?? .calm
    }

    static func tagEmotion(box: PreludeToolContextBox, label: String) async throws -> String {
        let ctx = ToolExecutionContext(modelContext: box.modelContext, session: box.session)
        try await TagEmotionTool(parsingRawLabel: label).execute(ctx)
        try? box.modelContext.save()
        return "Emotion tagged."
    }

    static func generateCard(box: PreludeToolContextBox, cardType: String, text: String) async throws -> String {
        let type = CardType(rawValue: cardType) ?? .emotionalState
        let ctx = ToolExecutionContext(modelContext: box.modelContext, session: box.session)
        try await GenerateCardTool(cardType: type, cardText: text).execute(ctx)
        try? box.modelContext.save()
        return "Card generated."
    }

    static func pastInsights(box: PreludeToolContextBox, query: String) -> String {
        let sid = box.session?.id
        return GetPastInsightsTool.recentInsightsSummary(
            modelContext: box.modelContext,
            excludingSessionId: sid,
            query: query,
            limit: 10
        )
    }

    static func endSession(box: PreludeToolContextBox) async throws -> String {
        let ctx = ToolExecutionContext(modelContext: box.modelContext, session: box.session)
        try await EndSessionTool().execute(ctx)
        try? box.modelContext.save()
        return "Session marked complete."
    }
}

struct SaveInsightFMTool: Tool {
    let name = "saveInsight"
    let description = "Save an emotionally significant insight for the session brief."
    let box: PreludeToolContextBox

    @Generable
    struct Arguments {
        @Guide(description: "One or two sentences capturing the insight")
        var text: String

        @Guide(
            description: """
                Emotion this insight carries: anxious, sad, angry, confused, hopeful, overwhelmed, frustrated, calm, happy, excited, grieving, reflective. \
                Prefer a **specific** label; use calm only if the note is emotionally flat. Omit only if unsure (host will infer from text).
                """
        )
        var emotionLabel: String?
    }

    func call(arguments: Arguments) async throws -> String {
        try await PreludeFMToolRunner.saveInsight(
            box: box,
            text: arguments.text,
            emotionLabel: arguments.emotionLabel ?? ""
        )
    }
}

struct TagEmotionFMTool: Tool {
    let name = "tagEmotion"
    let description = "Record the dominant emotion label for this session."
    let box: PreludeToolContextBox

    @Generable
    struct Arguments {
        @Guide(description: "Emotion key: anxious, sad, angry, confused, hopeful, overwhelmed, frustrated, calm, happy, excited, grieving, reflective")
        var emotionLabel: String
    }

    func call(arguments: Arguments) async throws -> String {
        try await PreludeFMToolRunner.tagEmotion(box: box, label: arguments.emotionLabel)
    }
}

struct GenerateCardFMTool: Tool {
    let name = "generateCard"
    let description = "Add a structured session card to the in-progress brief."
    let box: PreludeToolContextBox

    @Generable
    struct Arguments {
        @Guide(description: "Card type raw value, e.g. emotionalState, mainConcern, keyEmotion")
        var cardType: String
        @Guide(description: "Short card body in the user's voice where possible")
        var text: String
    }

    func call(arguments: Arguments) async throws -> String {
        try await PreludeFMToolRunner.generateCard(box: box, cardType: arguments.cardType, text: arguments.text)
    }
}

struct GetPastInsightsFMTool: Tool {
    let name = "getPastInsights"
    let description = "Summarize recent insights from earlier sessions for context."
    let box: PreludeToolContextBox

    @Generable
    struct Arguments {
        @Guide(description: "Optional keyword filter; use an empty string to summarize all recent insights.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        await PreludeFMToolRunner.pastInsights(box: box, query: arguments.query)
    }
}

struct EndSessionFMTool: Tool {
    let name = "endSession"
    let description = "Mark the reflection session as complete when the user is done."
    let box: PreludeToolContextBox

    @Generable
    struct Arguments {
        @Guide(description: "Set true when the user is finished with the reflection.")
        var confirmed: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        guard arguments.confirmed else {
            return "Okay — stay as long as you need."
        }
        return try await PreludeFMToolRunner.endSession(box: box)
    }
}

// MARK: - Run one model turn

/// **Not** `@MainActor`: `LanguageModelSession.respond` blocks its caller while the model runs tool calls.
/// Tools use SwiftData on the main actor (`PreludeFMToolRunner`). If `respond` ran on the main queue,
/// the app deadlocks after the first tool-using turn. Model work runs on the generic executor; only
/// session/context/agent mutations use `MainActor.run`.
enum PreludeFoundationModels {
    /// Keeps read-back prompts within a sensible size for on-device context limits.
    private static func truncatedTranscriptForReadBack(_ log: String, maxChars: Int = 3800) -> String {
        let t = log.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "(No user transcript lines yet — keep any recap tentative.)" }
        guard t.count > maxChars else { return t }
        return String(t.prefix(maxChars)) + "\n…(earlier user turns omitted.)"
    }

    /// Creates or returns a **LanguageModelSession** matching `includeTools` (recreates if mode changed).
    @available(iOS 26.0, *)
    private static func languageModelSession(
        agent: AgentController,
        box: PreludeToolContextBox,
        includeTools: Bool
    ) async -> LanguageModelSession? {
        await MainActor.run {
            if let existing = agent.foundationSessionStorage as? LanguageModelSession,
               agent.foundationSessionUsesTools == includeTools {
                return existing
            }
            agent.foundationSessionStorage = nil
            let tools: [any Tool] = includeTools ? PreludeFoundationToolFactory.makeTools(box: box) : []
            let lm = LanguageModelSession(
                model: .default,
                tools: tools
            ) {
                PreludeAgentPrompts.foundationInstructions()
            }
            agent.foundationSessionStorage = lm
            agent.foundationSessionUsesTools = includeTools
            PreludeFMLog.logger.debug("Created LanguageModelSession includeTools=\(includeTools) toolCount=\(tools.count)")
            return lm
        }
    }

    private static func logNSError(_ error: Error, prefix: String) {
        let ns = error as NSError
        PreludeFMLog.logger.error("\(prefix) \(error.localizedDescription) domain=\(ns.domain) code=\(ns.code)")
    }

    private static func resetFoundationSession(agent: AgentController) async {
        await MainActor.run {
            agent.foundationSessionStorage = nil
            agent.foundationSessionUsesTools = nil
        }
    }

    /// Opening uses a **tool-free** session and a minimal `@Generable` shape (tools + multi-field schema often fail first call).
    @available(iOS 26.0, *)
    nonisolated static func runOpening(
        agent: AgentController,
        modelContext: ModelContext,
        session: Session,
        box: PreludeToolContextBox
    ) async -> String? {
        guard PreludeModelAvailability.shouldAttemptFoundationModels else { return nil }

        await MainActor.run { box.session = session }

        let (preferredName, previousContext) = await MainActor.run {
            let name = UserSettings.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let prev = SessionStore.previousSessionOpeningContext(in: modelContext)
            return (name, prev)
        }

        let openingInstructions: String = {
            var chunks: [String] = [
                "The reflection session just started. The user has not spoken yet (phase warmOpen).",
                "Output only spokenResponse: a warm, brief invitation to settle in, ending with **one** open question about how they are arriving or what is on their mind (one or two sentences for text-to-speech)."
            ]
            if !preferredName.isEmpty {
                chunks.append("Preferred first name: \(preferredName) — greet with it once, naturally.")
            }
            if let prev = previousContext {
                chunks.append("Last completed reflection (continuity only; paraphrase, do not read as a bullet list): \(prev)")
                chunks.append("Optionally acknowledge one thread from last time in a short phrase, then invite what feels present **now**.")
            }
            return chunks.joined(separator: "\n\n")
        }()

        let promptOpening = Prompt {
            openingInstructions
        }

        do {
            guard let lm = await languageModelSession(agent: agent, box: box, includeTools: false) else {
                PreludeFMLog.logger.error("Opening: could not create LanguageModelSession")
                return nil
            }

            let response = try await lm.respond(
                to: promptOpening,
                generating: GenerableOpeningUtterance.self,
                includeSchemaInPrompt: true
            )

            let line = response.content.spokenResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                PreludeFMLog.logger.error("Opening: empty spokenResponse from GenerableOpeningUtterance")
                throw OpeningFallbackError.emptyUtterance
            }

            await MainActor.run {
                session.phase = agent.currentPhase
                try? modelContext.save()
            }
            return line
        } catch {
            logNSError(error, prefix: "Opening (GenerableOpeningUtterance) failed:")
            await resetFoundationSession(agent: agent)
        }

        // Fallback: same tool-free session, full decision schema + lenient action mapping.
        do {
            guard let lm = await languageModelSession(agent: agent, box: box, includeTools: false) else { return nil }
            let prompt = Prompt {
                openingInstructions
                "Output structured fields: action (prefer askQuestion), spokenResponse (warm brief TTS that **ends with an open question**), reasoning (may be empty)."
            }
            let response = try await lm.respond(
                to: prompt,
                generating: GenerableAgentDecision.self,
                includeSchemaInPrompt: true
            )
            guard let decision = AgentDecision(generable: response.content) else {
                PreludeFMLog.logger.error("Opening fallback: could not build AgentDecision from model output")
                return nil
            }
            await MainActor.run {
                session.phase = agent.currentPhase
                try? modelContext.save()
            }
            return decision.spokenResponse
        } catch {
            logNSError(error, prefix: "Opening fallback (GenerableAgentDecision) failed:")
            await resetFoundationSession(agent: agent)
            return nil
        }
    }

    private enum OpeningFallbackError: Error {
        case emptyUtterance
    }

    @available(iOS 26.0, *)
    nonisolated static func runTurn(
        agent: AgentController,
        userUtteranceForModel: String,
        rawTranscriptLine: String,
        modelContext: ModelContext,
        session: Session,
        box: PreludeToolContextBox
    ) async -> AgentDecision? {
        guard PreludeModelAvailability.shouldAttemptFoundationModels else { return nil }

        await MainActor.run { box.session = session }

        let (phaseLabel, phaseForPrompt, recapHint) = await MainActor.run {
            let eff = agent.effectivePhaseForIncomingTurn(rawTranscriptLine: rawTranscriptLine, session: session)
            return (eff.rawValue, eff, eff == .readBack)
        }
        let sessionTranscriptBlock = await MainActor.run {
            Self.truncatedTranscriptForReadBack(session.userTranscriptLog)
        }
        let prompt = Prompt {
            "Current conversation phase: \(phaseLabel)."
            "User said (latest turn): \(userUtteranceForModel)"
            """
            Respond with structured output: action (one of respond, askQuestion, saveInsight, reflectBack, readBackSummary, endSession), \
            spokenResponse for TTS, reasoning (may be brief). Use tools when helpful.
            """
            if recapHint {
                """
                Session transcript (user’s words, chronological — this is the **whole arc** so far):
                \(sessionTranscriptBlock)
                """
                """
                Phase note — read-back: spokenResponse must **synthesize across the transcript above** (themes, feelings, what matters for therapy) — \
                **not** paraphrase only the latest turn. One short natural paragraph, then invite them to add more or confirm it’s enough. \
                Prefer action **readBackSummary** when that recap is the main move. A single light check-in (e.g. whether that feels close) is fine; \
                do **not** add a separate deep exploratory question — recap and confirmation are the priority.
                """
            } else if phaseForPrompt == .closing {
                """
                Phase note — closing: warm, brief gratitude or encouragement; no new deep questions unless they are still adding something important.
                """
            } else {
                """
                If the user shared anything substantive, spokenResponse should **end with one gentle open question** \
                that deepens reflection (prefer action askQuestion). Skip the question only for minimal greetings, \
                safety/crisis, or a clear closing/read-back check-in as appropriate for the phase.
                """
            }
        }

        func runOnce(includeTools: Bool) async throws -> AgentDecision {
            guard let lm = await languageModelSession(agent: agent, box: box, includeTools: includeTools) else {
                throw TurnError.noSession
            }
            let response = try await lm.respond(
                to: prompt,
                generating: GenerableAgentDecision.self,
                includeSchemaInPrompt: true
            )
            guard let decision = AgentDecision(generable: response.content) else {
                PreludeFMLog.logger.error("Turn: empty spokenResponse or invalid payload from model")
                throw TurnError.emptyDecision
            }
            await MainActor.run {
                agent.recordUserTurnMetricsOnly(rawTranscriptLine)
                agent.applyPhaseAfterAgentTurn(userUtterance: rawTranscriptLine, session: session, modelAction: decision.action)
                session.phase = agent.currentPhase
                try? modelContext.save()
            }
            return decision
        }

        do {
            return try await runOnce(includeTools: true)
        } catch {
            logNSError(error, prefix: "Turn with tools failed; retrying text-only:")
            await resetFoundationSession(agent: agent)
        }

        do {
            return try await runOnce(includeTools: false)
        } catch {
            logNSError(error, prefix: "Turn text-only retry failed:")
            await resetFoundationSession(agent: agent)
            return nil
        }
    }

    private enum TurnError: Error {
        case noSession
        case emptyDecision
    }
}
#else
import Foundation

/// Ensures the target compiles when the active SDK does not ship **FoundationModels** (e.g. older Xcode).
enum PreludeFoundationModelsBuildPlaceholder {}
#endif
