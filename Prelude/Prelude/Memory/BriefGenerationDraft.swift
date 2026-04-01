import Foundation

/// In-memory brief assembled by **PreludeBriefAgent** tool calls before persisting `SessionBrief`.
@MainActor
final class BriefGenerationDraft {
    var sections: [String: String] = [:]

    func set(section raw: String, text: String) {
        let key = Self.normalizeSectionKey(raw)
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !key.isEmpty else { return }
        sections[key] = t
    }

    /// Pure string normalization — safe to call from any isolation (e.g. `BriefDraftSanitizer`).
    nonisolated static func normalizeSectionKey(_ raw: String) -> String {
        let k = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        switch k {
        case "how_i_showed_up", "emotionalstate":
            return "emotional_state"
        case "main_concern", "weighingonme", "weighing_on_me", "weighing_on_me_1", "weighing_1":
            return "weighing_on_me"
        case "second_theme", "secondary_focus", "secondary_theme", "weighing_on_me_2", "weighing_2":
            return "secondary_theme"
        case "third_theme", "tertiary_theme", "weighing_on_me_3", "weighing_3":
            return "tertiary_theme"
        case "keyemotion", "dominant_emotion":
            return "key_emotion"
        case "what_i_need_to_say", "implied_voice", "whattosay":
            return "what_to_say"
        case "thread", "unresolvedthread":
            return "unresolved_thread"
        case "therapygoal", "hope_for_session", "hope_for_today", "hope_for_today_1", "hope_1":
            return "therapy_goal"
        case "therapygoal2", "therapy_goal2", "therapy_goal_2", "hope_for_today_2", "second_hope", "hope_2":
            return "therapy_goal_2"
        case "pattern", "patternnote":
            return "pattern_note"
        case "emotional_read", "emotional_analysis", "affective_read", "tone":
            return "emotional_read"
        default:
            return k
        }
    }

    var hasMinimumContent: Bool {
        sections["weighing_on_me"] != nil
            || sections["what_to_say"] != nil
            || sections["emotional_state"] != nil
    }
}
