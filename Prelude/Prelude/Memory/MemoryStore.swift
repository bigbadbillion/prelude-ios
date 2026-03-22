import Foundation
import SwiftData

/// Seeds and migration helpers (PRD Phase 4). Mirrors Expo `AppContext` mock bootstrap.
/// The app’s single **`ModelContainer`** is owned by `PreludeApp` (`PreludeModelContainer.make()`); stores use the injected `ModelContext`.
enum MemoryStore {
    private static let didSeedKey = "prelude.didSeedSwiftData"

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: didSeedKey) else { return }

        var desc = FetchDescriptor<Session>()
        desc.fetchLimit = 1
        let existing = (try? context.fetch(desc)) ?? []
        guard existing.isEmpty else {
            UserDefaults.standard.set(true, forKey: didSeedKey)
            return
        }

        let s1 = Session(
            startedAt: Date().addingTimeInterval(-7 * 24 * 3600),
            completedAt: Date().addingTimeInterval(-7 * 24 * 3600 + 540),
            durationSeconds: 540,
            phase: .closing,
            dominantEmotion: .anxious
        )
        let b1 = SessionBrief(
            emotionalState: "Tender and a little fragile",
            themes: ["Work pressure", "Family distance", "Self-doubt"],
            patientWords: "I keep feeling like I'm holding everything together but I'm about to drop it all.",
            focusItems: [
                "The argument with my manager last Tuesday",
                "Why I cancel plans when I feel overwhelmed",
                "Whether I actually want to stay in this role",
            ],
            patternNote: "This is the third time you've described feeling like \"the responsible one\" who can't ask for help.",
            session: s1
        )
        s1.brief = b1

        let s2 = Session(
            startedAt: Date().addingTimeInterval(-14 * 24 * 3600),
            completedAt: Date().addingTimeInterval(-14 * 24 * 3600 + 660),
            durationSeconds: 660,
            phase: .closing,
            dominantEmotion: .hopeful
        )
        let b2 = SessionBrief(
            emotionalState: "Cautiously hopeful",
            themes: ["New opportunities", "Relationship patterns", "Identity"],
            patientWords: "I think I've been chasing what I thought I should want, not what I actually want.",
            focusItems: [
                "The decision about the new job offer",
                "How I talk to myself when things go wrong",
                "What \"rest\" actually means to me",
            ],
            session: s2
        )
        s2.brief = b2

        let s3 = Session(
            startedAt: Date().addingTimeInterval(-21 * 24 * 3600),
            completedAt: Date().addingTimeInterval(-21 * 24 * 3600 + 480),
            durationSeconds: 480,
            phase: .closing,
            dominantEmotion: .sad
        )
        let b3 = SessionBrief(
            emotionalState: "Carrying a quiet sadness",
            themes: ["Grief", "Disconnection", "Longing"],
            patientWords: "I miss who I was before everything changed.",
            focusItems: [
                "My relationship with my father",
                "The version of myself I feel I've lost",
                "Whether I'm allowed to still be sad about this",
            ],
            session: s3
        )
        s3.brief = b3

        context.insert(s1)
        context.insert(b1)
        context.insert(s2)
        context.insert(b2)
        context.insert(s3)
        context.insert(b3)

        let weekly = WeeklyBrief(
            weekStart: Date().addingTimeInterval(-7 * 24 * 3600),
            summary: """
            This week carried a familiar tension — the gap between how capable you appear to others and how precarious things feel from the inside. You returned, again, to the theme of carrying responsibility quietly, of being the one who keeps things together while quietly fraying at the edges.

            There was also something new this week: a flicker of clarity about what you actually want, beneath the noise of what you think you should want. That's worth sitting with.

            Your emotional range moved from anxious at the start of the week to something closer to resolve by the end — not peace, but groundedness.
            """,
            themes: ["Responsibility and burden", "Authentic desire", "Emotional self-concealment"],
            dominantEmotion: .anxious,
            suggestions: ["What would it look like to ask for help from one specific person this week?"],
            sessionIds: [s1.id.uuidString]
        )
        context.insert(weekly)

        try? context.save()
        UserDefaults.standard.set(true, forKey: didSeedKey)
    }
}
