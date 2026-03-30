import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var durationSeconds: Int
    var phaseRaw: String
    var dominantEmotionRaw: String?

    /// Finalized user speech-to-text lines, newest separated by blank lines — source of truth for session brief grounding.
    var userTranscriptLog: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Insight.session)
    var insights: [Insight] = []

    @Relationship(deleteRule: .cascade, inverse: \SessionCard.session)
    var cards: [SessionCard] = []

    @Relationship(deleteRule: .cascade, inverse: \SessionBrief.session)
    var brief: SessionBrief?

    @Relationship(deleteRule: .cascade, inverse: \EmotionalArc.session)
    var emotionalArc: EmotionalArc?

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        completedAt: Date? = nil,
        durationSeconds: Int = 0,
        phase: ConversationPhase = .warmOpen,
        dominantEmotion: EmotionLabel? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.phaseRaw = phase.rawValue
        self.dominantEmotionRaw = dominantEmotion?.rawValue
    }

    var phase: ConversationPhase {
        get { ConversationPhase(rawValue: phaseRaw) ?? .warmOpen }
        set { phaseRaw = newValue.rawValue }
    }

    var dominantEmotion: EmotionLabel? {
        get {
            guard let r = dominantEmotionRaw, !r.isEmpty else { return nil }
            return EmotionLabel.parseCanonicalKey(r)
        }
        set { dominantEmotionRaw = newValue?.rawValue }
    }

    func appendUserTurn(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if userTranscriptLog.isEmpty {
            userTranscriptLog = t
        } else {
            userTranscriptLog += "\n\n\(t)"
        }
    }
}

@Model
final class Insight {
    @Attribute(.unique) var id: UUID
    var text: String
    var emotionRaw: String
    var theme: String
    var importance: Int
    var timestamp: Date
    var session: Session?

    init(
        id: UUID = UUID(),
        text: String,
        emotion: EmotionLabel,
        theme: String,
        importance: Int,
        timestamp: Date = .now,
        session: Session? = nil
    ) {
        self.id = id
        self.text = text
        self.emotionRaw = emotion.rawValue
        self.theme = theme
        self.importance = importance
        self.timestamp = timestamp
        self.session = session
    }

    var emotion: EmotionLabel {
        get { EmotionLabel.parseCanonicalKey(emotionRaw) ?? .calm }
        set { emotionRaw = newValue.rawValue }
    }
}

@Model
final class SessionCard {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var text: String
    var session: Session?

    init(id: UUID = UUID(), type: CardType, text: String, session: Session? = nil) {
        self.id = id
        self.typeRaw = type.rawValue
        self.text = text
        self.session = session
    }

    var cardType: CardType {
        get { CardType(rawValue: typeRaw) ?? .emotionalState }
        set { typeRaw = newValue.rawValue }
    }
}

@Model
final class SessionBrief {
    @Attribute(.unique) var id: UUID
    var generatedAt: Date
    var emotionalState: String
    var themes: [String] = []
    var patientWords: String
    var focusItems: [String] = []
    var patternNote: String?
    /// Brief agent: short affective analysis of the generated brief text (tone, not clinical).
    var affectiveAnalysis: String = ""
    var session: Session?

    init(
        id: UUID = UUID(),
        generatedAt: Date = .now,
        emotionalState: String,
        themes: [String],
        patientWords: String,
        focusItems: [String],
        patternNote: String? = nil,
        affectiveAnalysis: String = "",
        session: Session? = nil
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.emotionalState = emotionalState
        self.themes = themes
        self.patientWords = patientWords
        self.focusItems = focusItems
        self.patternNote = patternNote
        self.affectiveAnalysis = affectiveAnalysis
        self.session = session
    }
}

@Model
final class EmotionalArc {
    @Attribute(.unique) var id: UUID
    var summary: String
    var session: Session?

    init(id: UUID = UUID(), summary: String = "", session: Session? = nil) {
        self.id = id
        self.summary = summary
        self.session = session
    }
}

@Model
final class WeeklyBrief {
    @Attribute(.unique) var id: UUID
    var weekStart: Date
    var summary: String
    var themes: [String] = []
    var dominantEmotionRaw: String
    var suggestions: [String] = []
    var sessionIds: [String] = []
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        weekStart: Date,
        summary: String,
        themes: [String],
        dominantEmotion: EmotionLabel,
        suggestions: [String],
        sessionIds: [String],
        generatedAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.summary = summary
        self.themes = themes
        self.dominantEmotionRaw = dominantEmotion.rawValue
        self.suggestions = suggestions
        self.sessionIds = sessionIds
        self.generatedAt = generatedAt
    }

    var dominantEmotion: EmotionLabel {
        get { EmotionLabel.parseCanonicalKey(dominantEmotionRaw) ?? .calm }
        set { dominantEmotionRaw = newValue.rawValue }
    }
}

enum PreludeModelContainer {
    static func make() -> ModelContainer {
        let schema = Schema([
            Session.self,
            Insight.self,
            SessionCard.self,
            SessionBrief.self,
            EmotionalArc.self,
            WeeklyBrief.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }
}
