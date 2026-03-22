#if canImport(FoundationModels)
import Foundation
import FoundationModels
import os

private enum PreludeBriefFMLog {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Prelude", category: "BriefFoundationModels")
}

// MARK: - @Generable outputs (keep fields simple — arrays are brittle on-device)

@Generable
struct GenerableSessionBriefOut {
    @Guide(description: "First person, short: how I showed up — **synthesized**, not a quote from USER SPOKE.")
    var emotionalState: String

    @Guide(description: "Main emotional weight or topic — **your summary**, not copied transcript wording.")
    var themeMain: String

    @Guide(description: "Second theme if any, distinct from themeMain; otherwise empty string.")
    var themeSecondary: String

    @Guide(
        description: """
            **Only field** that may closely match the user’s voice: one salient line for therapy \
            (max ~2 short sentences, under ~280 characters) — never the full transcript.
            """
    )
    var patientWords: String

    @Guide(description: "Key emotional quality or thread — short **inferred** label, not a USER SPOKE clip.")
    var focus1: String

    @Guide(description: "Second focus; empty if none — **new** wording, not another quote.")
    var focus2: String

    @Guide(description: "Third focus (e.g. goal for the hour); empty if none — inferred.")
    var focus3: String

    @Guide(description: "Cross-session pattern only if prompt supplies one that fits; else empty. Never paste USER SPOKE.")
    var patternNote: String
}

@Generable
struct GenerableWeeklyBriefOut {
    @Guide(description: "Three short paragraphs of warm narrative prose about the week — not bullet points.")
    var summary: String

    @Guide(description: "First recurring theme; empty if none.")
    var theme1: String

    @Guide(description: "Second theme; empty if none.")
    var theme2: String

    @Guide(description: "Third theme; empty if none.")
    var theme3: String

    @Guide(description: "Emotion label: anxious, sad, angry, confused, hopeful, overwhelmed, frustrated, neutral, grieving")
    var dominantEmotion: String

    @Guide(description: "One or two sentences: what emotion dominated and how it shifted through the week.")
    var emotionalShift: String

    @Guide(description: "One reflection prompt worth bringing to the next session.")
    var suggestion: String
}

@MainActor
enum PreludeBriefFoundationModels {
    @available(iOS 26.0, *)
    static func synthesizeSessionBrief(contextBundle: String, patternHint: String?) async -> GenerableSessionBriefOut? {
        guard PreludeModelAvailability.shouldAttemptFoundationModels else { return nil }

        let session = LanguageModelSession(model: .default, tools: []) {
            Instructions(
                """
                Fallback brief writer (no tools). Build a therapy-prep brief from USER SPOKE and saved material.

                **Only patientWords** may echo the user’s voice in one tight carry line (≤~280 characters, not the full log).
                emotionalState, themeMain, themeSecondary, focus1–3, patternNote: **synthesize** — do **not** copy sentences \
                from USER SPOKE. patternNote: empty unless a cross-session pattern is given in the prompt and clearly fits.
                Stay faithful to tone (e.g. good day → lighter). No clinical diagnosis. Unused string fields: empty.
                """
            )
        }

        let prompt = Prompt {
            contextBundle
            if let patternHint, !patternHint.isEmpty {
                "Cross-session pattern (patternNote only if it fits; else empty): \(patternHint)"
            }
            "Produce the structured brief."
        }

        do {
            let response = try await session.respond(
                to: prompt,
                generating: GenerableSessionBriefOut.self,
                includeSchemaInPrompt: true
            )
            return response.content
        } catch {
            let ns = error as NSError
            PreludeBriefFMLog.logger.error("Session brief FM failed: \(error.localizedDescription) domain=\(ns.domain) code=\(ns.code)")
            return nil
        }
    }

    @available(iOS 26.0, *)
    static func synthesizeWeeklyBrief(contextBundle: String) async -> GenerableWeeklyBriefOut? {
        guard PreludeModelAvailability.shouldAttemptFoundationModels else { return nil }

        let session = LanguageModelSession(model: .default, tools: []) {
            Instructions(
                """
                You are Prelude. You write a weekly reflection summary from the session data provided only.
                Do not invent events or emotions that are not supported by USER SPOKE or saved material.
                Three short paragraphs; include what dominated emotionally and what shifted when the data supports it.
                Unused theme fields should be empty strings.
                """
            )
        }

        let prompt = Prompt {
            "Week data (includes USER SPOKE verbatim per session where available):\n\(contextBundle)"
            "Write the structured weekly brief from this data only."
        }

        do {
            let response = try await session.respond(
                to: prompt,
                generating: GenerableWeeklyBriefOut.self,
                includeSchemaInPrompt: true
            )
            return response.content
        } catch {
            let ns = error as NSError
            PreludeBriefFMLog.logger.error("Weekly brief FM failed: \(error.localizedDescription) domain=\(ns.domain) code=\(ns.code)")
            return nil
        }
    }
}
#endif
