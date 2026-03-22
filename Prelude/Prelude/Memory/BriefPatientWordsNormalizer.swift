import Foundation

/// Keeps **what I need to say** (`patientWords`) to one salient snip — never the full session transcript.
enum BriefPatientWordsNormalizer {
    /// Target max length for the distilled line (about 2 short sentences).
    static let maxWhatToSayChars = 280

    /// If the model pasted the log or blew past the cap, replace with the strongest single user turn (or sentence-truncate).
    static func normalize(_ raw: String, userTranscriptLog transcript: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if shouldTreatAsFullTranscriptPaste(candidate: trimmed, log: log) {
            return salientExcerpt(from: log, maxChars: maxWhatToSayChars)
        }

        if trimmed.count <= maxWhatToSayChars {
            return trimmed
        }

        return truncateAtSentenceBoundary(trimmed, maxLen: maxWhatToSayChars)
    }

    private static func shouldTreatAsFullTranscriptPaste(candidate: String, log: String) -> Bool {
        guard log.count > 80 else { return false }
        if candidate.count >= log.count - 30 {
            return true
        }
        let ratio = Double(candidate.count) / Double(log.count)
        if ratio >= 0.82 {
            return true
        }
        let turns = userTurns(from: log)
        guard turns.count >= 2 else { return false }
        var contained = 0
        for turn in turns {
            let t = turn.trimmingCharacters(in: .whitespacesAndNewlines)
            guard t.count >= 25 else { continue }
            if candidate.localizedCaseInsensitiveContains(String(t.prefix(min(40, t.count)))) {
                contained += 1
            }
        }
        return contained >= min(turns.count, 3) && turns.count >= 2
    }

    private static func userTurns(from log: String) -> [String] {
        log.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Longest single user turn (one “beat”), capped; best simple proxy for salience without a second model pass.
    static func salientExcerpt(from log: String, maxChars: Int) -> String {
        let turns = userTurns(from: log)
        guard !turns.isEmpty else {
            return truncateAtSentenceBoundary(String(log.prefix(maxChars + 40)), maxLen: maxChars)
        }
        let best = turns.max(by: { $0.count < $1.count }) ?? turns[0]
        let trimmed = best.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxChars {
            return trimmed
        }
        return truncateAtSentenceBoundary(String(trimmed.prefix(maxChars + 60)), maxLen: maxChars)
    }

    /// Sentence / word boundary trim for brief fields (also used by `BriefDraftSanitizer`).
    static func truncateAtSentenceBoundary(_ s: String, maxLen: Int) -> String {
        guard s.count > maxLen else { return s }
        let prefix = String(s.prefix(maxLen))
        if let r = prefix.range(of: ". ", options: .backwards) {
            return String(prefix[..<r.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let r = prefix.range(of: "? ", options: .backwards) {
            return String(prefix[..<r.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let r = prefix.range(of: "! ", options: .backwards) {
            return String(prefix[..<r.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let sp = prefix.lastIndex(of: " ") {
            return String(prefix[..<sp]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
