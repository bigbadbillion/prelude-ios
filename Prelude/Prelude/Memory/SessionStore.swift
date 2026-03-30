import Foundation
import SwiftData

/// Session queries and helpers (PRD Phase 4).
enum SessionStore {
    @MainActor
    static func session(id: UUID, in modelContext: ModelContext) -> Session? {
        let sid = id
        let fd = FetchDescriptor<Session>(predicate: #Predicate { $0.id == sid })
        return try? modelContext.fetch(fd).first
    }

    /// Completed sessions, oldest first (for streak / timeline logic).
    @MainActor
    static func completedSessionsChronological(in modelContext: ModelContext) -> [Session] {
        let fd = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .forward)]
        )
        return (try? modelContext.fetch(fd)) ?? []
    }

    /// Sessions with `completedAt` in `[interval.start, interval.end)`.
    @MainActor
    static func completedSessions(in modelContext: ModelContext, interval: DateInterval) -> [Session] {
        let start = interval.start
        let end = interval.end
        return completedSessionsChronological(in: modelContext).filter { s in
            guard let c = s.completedAt else { return false }
            return c >= start && c < end
        }
    }

    @MainActor
    static func normalizedWeekStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    @MainActor
    static func isSameWeek(_ a: Date, _ b: Date, calendar: Calendar = .current) -> Bool {
        let ca = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: a)
        let cb = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: b)
        return ca.yearForWeekOfYear == cb.yearForWeekOfYear && ca.weekOfYear == cb.weekOfYear
    }

    /// Compact text for the **opening** model prompt: last completed session + optional cross-session theme (on-device FM).
    @MainActor
    static func previousSessionOpeningContext(in modelContext: ModelContext) -> String? {
        let completed = completedSessionsChronological(in: modelContext)
        guard let previous = completed.last else { return nil }

        var parts: [String] = []
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        if let ended = previous.completedAt {
            parts.append("Previous reflection ended \(df.string(from: ended)).")
        }

        if let brief = previous.brief {
            let em = brief.emotionalState.trimmingCharacters(in: .whitespacesAndNewlines)
            if !em.isEmpty { parts.append("Emotional tone then: \(em).") }
            let th = Array(brief.themes.prefix(4)).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if !th.isEmpty {
                parts.append("Themes: \(th.joined(separator: "; ")).")
            }
            let pw = brief.patientWords.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pw.isEmpty {
                let clip = String(pw.prefix(220))
                parts.append("Line they wanted to bring to therapy: \(clip)\(pw.count > 220 ? "…" : "")")
            }
        } else {
            if let em = previous.dominantEmotion {
                parts.append("Tagged tone then: \(em.rawValue).")
            }
            let log = previous.userTranscriptLog.trimmingCharacters(in: .whitespacesAndNewlines)
            if !log.isEmpty {
                let clip = String(log.prefix(260))
                parts.append("They spoke about: \(clip)\(log.count > 260 ? "…" : "")")
            }
        }

        if completed.count >= 2 {
            let recent = Array(completed.suffix(6))
            let ranked = PatternDetector.recurringThemes(from: recent, includeBriefThemes: true)
            if let top = ranked.first {
                let nt = PatternDetector.normalizeTheme(top)
                let hit = recent.filter { s in
                    PatternDetector.themeStrings(from: s, includeBriefThemes: true).contains(nt)
                }.count
                if hit >= 2 {
                    parts.append("Pattern across recent reflections: “\(top)” has come up more than once.")
                }
            }
        }

        let joined = parts.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }

    /// Sessions referenced by a weekly brief’s `sessionIds`, completed with a dominant emotion tag, oldest→newest, max six (Expo weekly emotional arc).
    @MainActor
    static func sessionsForWeeklyEmotionalArc(sessionIds idStrings: [String], in modelContext: ModelContext) -> [Session] {
        let resolved: [Session] = idStrings.compactMap { UUID(uuidString: $0) }.compactMap { session(id: $0, in: modelContext) }
        let eligible = resolved.filter { s in
            guard s.completedAt != nil else { return false }
            return s.dominantEmotion != nil || s.brief != nil
        }
        let sorted = eligible.sorted { ($0.completedAt!) < ($1.completedAt!) }
        return Array(sorted.suffix(6))
    }
}
