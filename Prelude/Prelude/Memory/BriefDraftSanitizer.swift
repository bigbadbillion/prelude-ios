import Foundation

/// Post-processes brief draft lines so only **what_to_say** may closely track USER SPOKE.
/// Other sections should read like synthesized therapy-prep notes, not transcript snippets.
enum BriefDraftSanitizer {
    /// Sections where pasted transcript lines are invalid (except `what_to_say`, handled elsewhere).
    private static let antiVerbatimKeys: Set<String> = [
        "emotional_state",
        "weighing_on_me",
        "secondary_theme",
        "key_emotion",
        "unresolved_thread",
        "therapy_goal",
        "pattern_note",
        "emotional_read",
    ]

    private static let maxLen: [String: Int] = [
        "emotional_state": 120,
        "weighing_on_me": 140,
        "secondary_theme": 120,
        "key_emotion": 72,
        "unresolved_thread": 200,
        "therapy_goal": 200,
        "pattern_note": 220,
        "emotional_read": 520,
    ]

    static func sanitize(
        sectionKey: String,
        text raw: String,
        userTranscriptLog transcript: String,
        patternHint: String?
    ) -> String {
        let key = BriefGenerationDraft.normalizeSectionKey(sectionKey)
        guard antiVerbatimKeys.contains(key) else { return raw }

        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return t }

        if key == "pattern_note" {
            t = sanitizePatternNote(t, transcript: transcript, patternHint: patternHint)
        } else if looksLikeTranscriptPaste(candidate: t, transcript: transcript) {
            t = ""
        }

        if let cap = maxLen[key], t.count > cap {
            t = BriefPatientWordsNormalizer.truncateAtSentenceBoundary(String(t.prefix(cap + 40)), maxLen: cap)
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sanitizePatternNote(_ text: String, transcript: String, patternHint: String?) -> String {
        let hint = patternHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if hint.isEmpty {
            if looksLikeTranscriptPaste(candidate: text, transcript: transcript) {
                return ""
            }
            return text
        }
        if looksLikeTranscriptPaste(candidate: text, transcript: transcript), !text.localizedCaseInsensitiveContains(hint.prefix(min(24, hint.count))) {
            return hint
        }
        return text
    }

    /// True when the model likely copied USER SPOKE into a field that should be synthesized.
    static func looksLikeTranscriptPaste(candidate: String, transcript: String) -> Bool {
        let c = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard c.count >= 18, log.count >= 30 else { return false }

        let lc = c.lowercased()
        let lt = log.lowercased()

        if lt.contains(lc) { return true }

        for turn in log.components(separatedBy: "\n\n").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
            let low = turn.lowercased()
            guard low.count >= 24 else { continue }
            if lc.contains(low) || low.contains(lc) { return true }
            if longestSharedPrefixLength(lc, low) >= 28 { return true }
        }

        let words = lc.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count > 2 }
        guard words.count >= 4 else { return false }
        var search = lt
        var matched = 0
        for w in words {
            guard let r = search.range(of: w) else { break }
            matched += 1
            search = String(search[r.upperBound...])
        }
        return Double(matched) / Double(words.count) >= 0.72 && matched >= 4
    }

    private static func longestSharedPrefixLength(_ a: String, _ b: String) -> Int {
        let ac = Array(a)
        let bc = Array(b)
        var n = 0
        let limit = min(ac.count, bc.count)
        while n < limit, ac[n] == bc[n] { n += 1 }
        return n
    }
}
