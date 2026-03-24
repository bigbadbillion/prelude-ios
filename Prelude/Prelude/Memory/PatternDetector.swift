import Foundation

/// Cross-session theme analysis (PRD F5; pattern card = 3+ **consecutive** sessions per prelude-ios-prd §4.6).
enum PatternDetector {
    static func normalizeTheme(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Theme tokens from insights and (optionally) brief themes — excludes empty.
    static func themeStrings(from session: Session, includeBriefThemes: Bool) -> Set<String> {
        var set = Set<String>()
        for i in session.insights {
            let n = normalizeTheme(i.theme)
            if !n.isEmpty { set.insert(n) }
        }
        if includeBriefThemes, let b = session.brief {
            for t in b.themes {
                let n = normalizeTheme(t)
                if !n.isEmpty { set.insert(n) }
            }
        }
        return set
    }

    /// Per-session theme set for pattern streaks. For `focusSessionId`, omit brief themes (brief not written yet).
    static func themeStrings(for session: Session, focusSessionId: UUID) -> Set<String> {
        let includeBrief = session.id != focusSessionId
        return themeStrings(from: session, includeBriefThemes: includeBrief)
    }

    /// Recurring themes by frequency across the given sessions (chronology irrelevant).
    static func recurringThemes(from sessions: [Session], includeBriefThemes: Bool = true) -> [String] {
        var counts: [String: Int] = [:]
        for s in sessions {
            for t in themeStrings(from: s, includeBriefThemes: includeBriefThemes) {
                counts[t, default: 0] += 1
            }
        }
        return counts.keys.sorted { lhs, rhs in
            if counts[lhs]! != counts[rhs]! { return counts[lhs]! > counts[rhs]! }
            return lhs < rhs
        }
    }

    private static func longestConsecutiveStreak(
        theme: String,
        orderedSessions: [Session],
        themeSet: (Session) -> Set<String>
    ) -> Int {
        var run = 0
        var best = 0
        for s in orderedSessions {
            if themeSet(s).contains(theme) {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best
    }

    /// Pattern note when a theme appears in **3+ consecutive** sessions (oldest → newest by `completedAt`).
    /// Pass completed sessions **including** the session being briefed; that session is identified by `focusSessionId`.
    static func consecutiveStreakPatternNote(
        completedSessionsAscending: [Session],
        focusSessionId: UUID
    ) -> String? {
        let ordered = completedSessionsAscending.filter { $0.completedAt != nil }
        guard ordered.count >= 3 else { return nil }

        var candidateThemes = Set<String>()
        for s in ordered {
            candidateThemes.formUnion(themeStrings(for: s, focusSessionId: focusSessionId))
        }

        var bestTheme: String?
        var bestStreak = 0
        for t in candidateThemes {
            let streak = longestConsecutiveStreak(theme: t, orderedSessions: ordered) { s in
                themeStrings(for: s, focusSessionId: focusSessionId)
            }
            if streak >= 3, streak > bestStreak {
                bestStreak = streak
                bestTheme = t
            }
        }

        guard let theme = bestTheme else { return nil }
        let display = theme.prefix(1).uppercased() + theme.dropFirst()
        return "The theme “\(display)” has shown up in several reflections in a row — worth naming with your therapist."
    }

    /// Softer signal when no 3-session streak: a theme appearing in **2+** of the most recent completed sessions (insights + brief themes).
    static func recurringThemeHintAmongRecent(completedNewestFirst: [Session], maxSessions: Int = 6) -> String? {
        let slice = Array(completedNewestFirst.prefix(maxSessions))
        guard slice.count >= 2 else { return nil }
        var counts: [String: Int] = [:]
        for s in slice {
            for t in themeStrings(from: s, includeBriefThemes: true) {
                counts[t, default: 0] += 1
            }
        }
        guard let best = counts.max(by: { $0.value < $1.value }), best.value >= 2 else { return nil }
        let display = best.key.prefix(1).uppercased() + best.key.dropFirst()
        return "“\(display)” has surfaced in multiple recent reflections — worth watching between sessions."
    }

    /// Human-readable summary for tools / debugging.
    static func summaryLines(from sessions: [Session], focusSessionId: UUID?) -> String {
        let themes: [String]
        if let fid = focusSessionId {
            var counts: [String: Int] = [:]
            for s in sessions {
                for t in themeStrings(for: s, focusSessionId: fid) {
                    counts[t, default: 0] += 1
                }
            }
            themes = counts.keys.sorted { lhs, rhs in
                if counts[lhs]! != counts[rhs]! { return counts[lhs]! > counts[rhs]! }
                return lhs < rhs
            }.prefix(5).map(\.self)
        } else {
            themes = Array(recurringThemes(from: sessions, includeBriefThemes: true).prefix(5))
        }
        if themes.isEmpty {
            return "No cross-session themes detected yet."
        }
        return "Recurring themes: " + themes.joined(separator: "; ") + "."
    }
}
