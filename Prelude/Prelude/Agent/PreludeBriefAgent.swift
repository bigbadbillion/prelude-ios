#if canImport(FoundationModels)
import Foundation
import FoundationModels
import os
import SwiftData

private enum PreludeBriefAgentLog {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Prelude", category: "BriefAgent")
}

// MARK: - Tool context

final class PreludeBriefAgentBox: @unchecked Sendable {
    let modelContext: ModelContext
    let session: Session
    let draft: BriefGenerationDraft
    /// Cross-session pattern line (if any); used to validate `pattern_note` and sanitizer.
    let patternHint: String?

    init(modelContext: ModelContext, session: Session, draft: BriefGenerationDraft, patternHint: String?) {
        self.modelContext = modelContext
        self.session = session
        self.draft = draft
        self.patternHint = patternHint
    }
}

// MARK: - Tool: set brief section

/// The brief agent has **one** tool: `setBriefSection` (each section is a separate call).
struct SetBriefSectionFMTool: Tool {
    let name = "setBriefSection"
    let description = """
        Set one brief card field. Call once per section you fill.

        **Only `what_to_say` may closely use the user’s own wording** (one distilled carry line, ≤~280 characters).

        **All other sections must be short synthesized therapy-prep language** — your summary of what matters, \
        **not** sentences copied from USER SPOKE. No duplicate content across sections.

        **pattern_note**: only when the supplied cross-session pattern clearly fits; otherwise **omit** this call. \
        Never paste USER SPOKE into pattern_note.
        """
    let box: PreludeBriefAgentBox

    @Generable
    struct Arguments {
        @Guide(
            description: """
                Section key: emotional_state, weighing_on_me, secondary_theme, key_emotion, what_to_say, \
                unresolved_thread, therapy_goal, pattern_note, emotional_read
                """
        )
        var section: String

        @Guide(
            description: """
                Card text. **what_to_say**: one salient first-person line to say in session (may echo their voice; not the full log). \
                **weighing_on_me**: one short synthesized line naming the emotional weight (do not quote USER SPOKE). \
                **key_emotion**: a brief emotion label or quality (e.g. “Quiet pride mixed with fatigue”) — not a transcript clip. \
                **unresolved_thread** / **therapy_goal**: infer what’s unfinished and what they need from the hour — new wording. \
                **emotional_read**: 2–4 sentences on tone of the brief you wrote. \
                **pattern_note**: only if cross-session pattern fits; else skip the tool call.
                """
        )
        var text: String
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            let key = BriefGenerationDraft.normalizeSectionKey(arguments.section)
            let payload: String
            if key == "what_to_say" {
                payload = BriefPatientWordsNormalizer.normalize(
                    arguments.text,
                    userTranscriptLog: box.session.userTranscriptLog
                )
            } else {
                payload = BriefDraftSanitizer.sanitize(
                    sectionKey: key,
                    text: arguments.text,
                    userTranscriptLog: box.session.userTranscriptLog,
                    patternHint: box.patternHint
                )
            }
            box.draft.set(section: arguments.section, text: payload)
        }
        return "OK"
    }
}

// MARK: - Structured completion

@Generable
struct GenerableBriefAgentAck {
    @Guide(description: "The word 'done' after all intended setBriefSection calls are complete.")
    var status: String
}

// MARK: - Brief agent run loop

/// Not `@MainActor`: `LanguageModelSession.respond` must not run on the main queue while tools call `MainActor.run` (SwiftData draft).
enum PreludeBriefAgent {
    private static let instructionsString = """
        You are Prelude’s **session-brief writer** (not the live coach). Build a **therapy-prep worksheet** from USER SPOKE \
        plus saved insights/cards: clear, non-redundant cards the user can glance at before a session.

        **Voice rule (critical)** \
        - **Only `what_to_say`** should sound like the user’s own line to speak (tight paraphrase / carry sentence, first person). \
        - **Every other section is your synthesis** — short, first person where natural, but **do not copy phrases or sentences \
        from USER SPOKE**. If you catch yourself pasting their words into emotional_state, key_emotion, thread, goal, or pattern — rewrite.

        **Section meanings (prep worksheets often ask: what am I noticing? what’s unfinished? what do I need from the hour?)** \
        - **emotional_state**: How I showed up emotionally today — one short line you infer (not a quote). \
        - **weighing_on_me**: The main emotional weight or situation — **one synthesized line** (not verbatim from the log). \
        - **secondary_theme**: Optional second angle — **must differ** from weighing_on_me; skip the tool if none. \
        - **key_emotion**: Compact label for the emotional quality (a few words; not a sentence from the transcript). \
        - **what_to_say**: Exactly **one** distilled sentence (or two very short ones); the line they most need to say aloud; ≤~280 characters; no transcript dump. \
        - **unresolved_thread**: What feels **unfinished** or tense — infer in **new** words. \
        - **therapy_goal**: What they need **from this therapy hour** (clarity, pacing, being seen, etc.) — infer; not a random quote. \
        - **pattern_note**: **Only** if the cross-session pattern in the prompt clearly fits **this** conversation. Otherwise **omit** the tool call. Never paste USER SPOKE here. \
        - **emotional_read**: 2–4 sentences on how the **brief you wrote** reads (warmth, tension, hope) — not diagnosis.

        **De-duplication**: Each section must add **distinct** information. Do not restate the same idea across cards.

        Do not invent crises or severe symptoms they did not imply. Use **setBriefSection** once per section, then structured status **done**.
        """

    @available(iOS 26.0, *)
    nonisolated static func run(
        contextBundle: String,
        patternHint: String?,
        modelContext: ModelContext,
        session: Session,
        draft: BriefGenerationDraft
    ) async -> Bool {
        guard PreludeModelAvailability.shouldAttemptFoundationModels else { return false }

        let tools: [any Tool] = await MainActor.run {
            let box = PreludeBriefAgentBox(
                modelContext: modelContext,
                session: session,
                draft: draft,
                patternHint: patternHint
            )
            return [SetBriefSectionFMTool(box: box)]
        }

        let sessionLM = LanguageModelSession(model: .default, tools: tools) {
            Instructions(instructionsString)
        }

        let prompt = Prompt {
            "=== MATERIAL ==="
            contextBundle
            if let patternHint, !patternHint.isEmpty {
                "=== CROSS-SESSION PATTERN (pattern_note ONLY if this clearly applies to THIS session; else skip pattern_note entirely) ==="
                patternHint
            }
            """
            === TASK ===
            Call setBriefSection for: emotional_state, weighing_on_me, key_emotion, what_to_say, \
            unresolved_thread, therapy_goal, emotional_read. \
            Optional: secondary_theme (only if distinct), pattern_note (only if cross-session pattern fits). \
            Then respond with status 'done'.
            """
        }

        do {
            _ = try await sessionLM.respond(
                to: prompt,
                generating: GenerableBriefAgentAck.self,
                includeSchemaInPrompt: true
            )
            return await MainActor.run { draft.hasMinimumContent }
        } catch {
            let ns = error as NSError
            PreludeBriefAgentLog.logger.error("Brief agent failed: \(error.localizedDescription) domain=\(ns.domain) code=\(ns.code)")
            return false
        }
    }
}
#endif
