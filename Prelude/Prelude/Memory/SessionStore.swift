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
