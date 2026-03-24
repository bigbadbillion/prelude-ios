import Foundation
import SwiftData

/// SwiftData helpers: the shared **`ModelContainer`** lives in `PreludeApp` (`PreludeModelContainer.make()`).
enum MemoryStore {
    /// Deletes the session (cascade: brief, insights, cards, emotional arc) and removes its id from every `WeeklyBrief.sessionIds`.
    @MainActor
    static func deleteSessionAndPruneWeekly(sessionId: UUID, modelContext: ModelContext) throws {
        let idString = sessionId.uuidString
        let weeks = try modelContext.fetch(FetchDescriptor<WeeklyBrief>())
        for w in weeks {
            w.sessionIds = w.sessionIds.filter { $0 != idString }
        }
        guard let session = SessionStore.session(id: sessionId, in: modelContext) else {
            try modelContext.save()
            return
        }
        modelContext.delete(session)
        try modelContext.save()
    }

    /// Deletes all persisted models and clears Prelude `UserDefaults` keys (name, disclaimer).
    @MainActor
    static func clearAllLocalData(modelContext: ModelContext) throws {
        let weeks = try modelContext.fetch(FetchDescriptor<WeeklyBrief>())
        for w in weeks {
            modelContext.delete(w)
        }
        let sessions = try modelContext.fetch(FetchDescriptor<Session>())
        for s in sessions {
            modelContext.delete(s)
        }
        try modelContext.save()
        UserSettings.clearAllSavedKeys()
    }
}
