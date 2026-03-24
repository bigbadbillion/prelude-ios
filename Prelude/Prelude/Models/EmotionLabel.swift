import Foundation

enum EmotionLabel: String, Codable, CaseIterable, Sendable {
    case anxious, sad, angry, confused, hopeful, overwhelmed, frustrated, neutral, grieving

    /// Strict parse for model-emitted keys (trim + lowercase `rawValue` only). Prefer this over substring inference.
    static func parseCanonicalKey(_ raw: String) -> EmotionLabel? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !t.isEmpty else { return nil }
        return EmotionLabel(rawValue: t)
    }

    /// First emotion label with a **whole-word** match in `text`, **skipping** matches immediately preceded by simple negation
    /// (e.g. “not anxious”, “don’t feel sad”). Longer `rawValue`s are tried first so `overwhelmed` wins over embedded substrings.
    static func firstMentioned(in text: String) -> EmotionLabel? {
        let lower = text.lowercased()
        for label in EmotionLabel.allCases.sorted(by: { $0.rawValue.count > $1.rawValue.count }) {
            for range in wholeWordRanges(of: label.rawValue, in: lower) {
                if !isPrecededBySimpleNegation(in: lower, matchStart: range.lowerBound) {
                    return label
                }
            }
        }
        return nil
    }

    private static func wholeWordRanges(of word: String, in text: String) -> [Range<String.Index>] {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        guard let re = try? NSRegularExpression(pattern: "\\b\(escaped)\\b", options: []) else { return [] }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var out: [Range<String.Index>] = []
        re.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
            guard let match, match.numberOfRanges > 0 else { return }
            let r = match.range(at: 0)
            guard r.location != NSNotFound, let sr = Range(r, in: text) else { return }
            out.append(sr)
        }
        return out
    }

    /// Looks at the tail of text before `matchStart` for a negation marker that scopes toward the emotion word.
    /// Omits generic `n't` (e.g. **can’t**) to avoid “I can’t explain how anxious…” false positives.
    private static func isPrecededBySimpleNegation(in s: String, matchStart: String.Index) -> Bool {
        let dist = s.distance(from: s.startIndex, to: matchStart)
        guard dist > 0 else { return false }
        let lookback = min(56, dist)
        let start = s.index(matchStart, offsetBy: -lookback)
        let window = String(s[start..<matchStart])

        // Negation + up to two intervening tokens, anchored at end of window (right before the emotion word).
        let pattern = #"(?i)(?:\bnot\b|\bnever\b|\bwithout\b|\bneither\b|\bnor\b|\bhardly\b|\bbarely\b|\bcannot\b|\bnothing\b|\bnobody\b|\bno\b|\bisn't\b|\bisnt\b|\baren't\b|\barent\b|\bwasn't\b|\bwasnt\b|\bweren't\b|\bwerent\b|\bdon't\b|\bdont\b|\bdoesn't\b|\bdoesnt\b|\bdidn't\b|\bdidnt\b|\bwon't\b|\bwont\b|\bwouldn't\b|\bwouldnt\b|\bcouldn't\b|\bcouldnt\b|\bshouldn't\b|\bshouldnt\b)(?:\s+\S+){0,2}\s*$"#

        return window.range(of: pattern, options: .regularExpression) != nil
    }
}
