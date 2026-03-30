import Foundation
import SwiftData

/// Session + weekly brief persistence and synthesis (PRD Phase 4, F4 / F6).
@MainActor
enum BriefStore {
    private static let maxBundleChars = 6_000

    // MARK: - Session brief

    /// Builds and saves `SessionBrief` for the session. Replaces an existing brief.
    /// Primary path: **PreludeBriefAgent** (dedicated `LanguageModelSession` + `setBriefSection` tool). Fallback: single-shot FM, then cards/insights.
    static func synthesizeAndAttachSessionBrief(modelContext: ModelContext, sessionId: UUID) async {
        guard let session = SessionStore.session(id: sessionId, in: modelContext) else { return }

        if let existing = session.brief {
            modelContext.delete(existing)
            session.brief = nil
        }

        let chronological = SessionStore.completedSessionsChronological(in: modelContext)
        let patternNote = PatternDetector.consecutiveStreakPatternNote(
            completedSessionsAscending: chronological,
            focusSessionId: sessionId
        )

        let bundle = sessionContextBundle(session: session, cap: maxBundleChars)

        var emotionalState = "Present and reflecting"
        var themes: [String] = []
        var patientWords = ""
        var focusItems: [String] = []
        var resolvedPattern = patternNote
        var affectiveAnalysis = ""

        let draft = BriefGenerationDraft()
        var usedAgent = false
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            usedAgent = await PreludeBriefAgent.run(
                contextBundle: bundle,
                patternHint: patternNote,
                modelContext: modelContext,
                session: session,
                draft: draft
            )
        }
        #endif

        if usedAgent, draft.hasMinimumContent {
            let mapped = mapDraftToSessionBriefFields(
                draft: draft,
                session: session,
                patternNoteFromDetector: patternNote
            )
            emotionalState = mapped.emotionalState
            themes = mapped.themes
            patientWords = mapped.patientWords
            focusItems = mapped.focusItems
            resolvedPattern = mapped.patternNote
            affectiveAnalysis = mapped.affectiveAnalysis
        } else {
            var usedOneShot = false
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                if let out = await PreludeBriefFoundationModels.synthesizeSessionBrief(
                    contextBundle: bundle,
                    patternHint: patternNote
                ) {
                    usedOneShot = true
                    let log = session.userTranscriptLog
                    let hint = patternNote
                    let esCleaned = BriefDraftSanitizer.sanitize(
                        sectionKey: "emotional_state",
                        text: trim(out.emotionalState, fallback: emotionalState),
                        userTranscriptLog: log,
                        patternHint: hint
                    )
                    emotionalState = esCleaned.isEmpty ? "Present and reflecting" : esCleaned
                    var th: [String] = []
                    let main = BriefDraftSanitizer.sanitize(
                        sectionKey: "weighing_on_me",
                        text: trim(out.themeMain, fallback: ""),
                        userTranscriptLog: log,
                        patternHint: hint
                    )
                    if !main.isEmpty { th.append(main) }
                    let sec = BriefDraftSanitizer.sanitize(
                        sectionKey: "secondary_theme",
                        text: trim(out.themeSecondary, fallback: ""),
                        userTranscriptLog: log,
                        patternHint: hint
                    )
                    if !sec.isEmpty { th.append(sec) }
                    themes = th
                    patientWords = BriefPatientWordsNormalizer.normalize(
                        trim(out.patientWords, fallback: ""),
                        userTranscriptLog: log
                    )
                    let focusKeys = ["key_emotion", "unresolved_thread", "therapy_goal"]
                    focusItems = [out.focus1, out.focus2, out.focus3].enumerated().compactMap { i, raw in
                        let t = trim(raw, fallback: "")
                        guard !t.isEmpty else { return nil }
                        let key = focusKeys[min(i, focusKeys.count - 1)]
                        let c = BriefDraftSanitizer.sanitize(
                            sectionKey: key,
                            text: t,
                            userTranscriptLog: log,
                            patternHint: hint
                        )
                        return c.isEmpty ? nil : c
                    }
                    let pn = BriefDraftSanitizer.sanitize(
                        sectionKey: "pattern_note",
                        text: trim(out.patternNote, fallback: ""),
                        userTranscriptLog: log,
                        patternHint: hint
                    )
                    if !pn.isEmpty {
                        resolvedPattern = pn
                    }
                    if let raw = out.dominantEmotionKey, let label = EmotionLabel.parseCanonicalKey(raw) {
                        session.dominantEmotion = label
                    }
                }
            }
            #endif
            if !usedOneShot {
                let fb = assembleFallbackSessionBrief(session: session, patternNote: resolvedPattern)
                emotionalState = fb.emotionalState
                themes = fb.themes
                patientWords = fb.patientWords
                focusItems = fb.focusItems
                resolvedPattern = fb.patternNote
            }
        }

        if themes.isEmpty {
            themes = [defaultWeighingQuote(from: session)]
        }

        if patientWords.isEmpty {
            patientWords = firstUserAnchoredQuote(from: session)
                ?? "I want to bring what mattered today into the room honestly."
        }

        patientWords = BriefPatientWordsNormalizer.normalize(
            patientWords,
            userTranscriptLog: session.userTranscriptLog
        )
        if patientWords.isEmpty {
            patientWords = "I want to bring what mattered today into the room honestly."
        }

        if focusItems.isEmpty {
            focusItems = ["What matters most to say out loud"]
        }

        let brief = SessionBrief(
            emotionalState: emotionalState,
            themes: themes,
            patientWords: patientWords,
            focusItems: focusItems,
            patternNote: resolvedPattern,
            affectiveAnalysis: affectiveAnalysis,
            session: session
        )
        modelContext.insert(brief)
        session.brief = brief
        refineDominantEmotionIfWeak(session: session, brief: brief)
    }

    /// Fallback when structured brief output (or live tag) did not set a **non-calm** dominant: substring heuristic on brief text, then insight vote.
    private static func refineDominantEmotionIfWeak(session: Session, brief: SessionBrief) {
        let tag = session.dominantEmotion
        guard tag == nil || tag == .calm else { return }

        let corpus = [
            brief.emotionalState,
            brief.affectiveAnalysis,
            brief.themes.joined(separator: " "),
            brief.focusItems.joined(separator: " "),
        ].joined(separator: "\n")
        if let inferred = EmotionLabel.firstMentioned(in: corpus), inferred != .calm {
            session.dominantEmotion = inferred
            return
        }

        let votes = session.insights.map(\.emotion).filter { $0 != .calm }
        guard !votes.isEmpty else { return }
        let grouped = Dictionary(grouping: votes, by: { $0 })
        if let best = grouped.max(by: { $0.value.count < $1.value.count })?.key {
            session.dominantEmotion = best
        }
    }

    private static func mapDraftToSessionBriefFields(
        draft: BriefGenerationDraft,
        session: Session,
        patternNoteFromDetector: String?
    ) -> (
        emotionalState: String,
        themes: [String],
        patientWords: String,
        focusItems: [String],
        patternNote: String?,
        affectiveAnalysis: String
    ) {
        let log = session.userTranscriptLog
        let hint = patternNoteFromDetector

        func cleaned(_ key: String, _ raw: String?) -> String {
            let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return BriefDraftSanitizer.sanitize(sectionKey: key, text: t, userTranscriptLog: log, patternHint: hint)
        }

        let es = cleaned("emotional_state", draft.sections["emotional_state"])
        let weighing = cleaned("weighing_on_me", draft.sections["weighing_on_me"])
        let secondary = cleaned("secondary_theme", draft.sections["secondary_theme"])
        let keyEm = cleaned("key_emotion", draft.sections["key_emotion"])
        var whatToSay = (draft.sections["what_to_say"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        whatToSay = BriefPatientWordsNormalizer.normalize(whatToSay, userTranscriptLog: log)
        let thread = cleaned("unresolved_thread", draft.sections["unresolved_thread"])
        let goal = cleaned("therapy_goal", draft.sections["therapy_goal"])
        let patternFromModel = cleaned("pattern_note", draft.sections["pattern_note"])
        let affective = cleaned("emotional_read", draft.sections["emotional_read"])

        var themes: [String] = []
        let w = weighing.isEmpty ? defaultWeighingQuote(from: session) : weighing
        themes.append(w)
        if !secondary.isEmpty {
            themes.append(secondary)
        }

        var focusItems: [String] = []
        if !keyEm.isEmpty { focusItems.append(keyEm) }
        if !thread.isEmpty { focusItems.append(thread) }
        if !goal.isEmpty { focusItems.append(goal) }

        let resolvedPattern: String?
        if !patternFromModel.isEmpty {
            resolvedPattern = patternFromModel
        } else {
            resolvedPattern = patternNoteFromDetector
        }

        return (
            es.isEmpty ? "Present and reflecting" : es,
            themes,
            whatToSay,
            focusItems,
            resolvedPattern,
            affective
        )
    }

    /// Synthesized line for **weighing on me** when the agent omits it (not a transcript excerpt).
    private static func defaultWeighingQuote(from session: Session) -> String {
        let sortedInsights = session.insights.sorted(by: { $0.timestamp < $1.timestamp })
        if let insight = sortedInsights.first {
            let theme = insight.theme.trimmingCharacters(in: .whitespacesAndNewlines)
            if !theme.isEmpty {
                return "Showing up with something around \(theme.lowercased())"
            }
        }
        if let em = session.dominantEmotion {
            return "Carrying \(em.rawValue) into the room today"
        }
        return "What I'm sorting through as I arrive"
    }

    private static func trim(_ s: String, fallback: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallback : t
    }

    private static func sessionContextBundle(session: Session, cap: Int) -> String {
        var lines: [String] = []
        let rawLog = session.userTranscriptLog.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawLog.isEmpty {
            lines.append("USER SPOKE: (no transcript captured — use only saved insights/cards below, or plain minimal lines; do not invent struggles.)")
        } else {
            lines.append("USER SPOKE (verbatim, chronological — primary source of truth):")
            lines.append(rawLog)
        }
        lines.append("Dominant emotion tag: \(session.dominantEmotion?.rawValue ?? "unknown")")
        for i in session.insights.sorted(by: { $0.timestamp < $1.timestamp }) {
            lines.append("Insight (\(i.emotion.rawValue), \(i.theme)): \(i.text)")
        }
        for c in session.cards.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            lines.append("Card \(c.cardType.rawValue): \(c.text)")
        }
        if let arc = session.emotionalArc, !arc.summary.isEmpty {
            lines.append("Emotional arc note: \(arc.summary)")
        }
        var text = lines.joined(separator: "\n")
        if text.count > cap {
            text = String(text.prefix(cap)) + "\n…"
        }
        return text
    }

    private static func firstUserAnchoredQuote(from session: Session) -> String? {
        for c in session.cards where c.cardType == .whatToSay {
            let t = c.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return String(t.prefix(400)) }
        }
        for i in session.insights {
            let t = i.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return String(t.prefix(400)) }
        }
        return nil
    }

    static func assembleFallbackSessionBrief(session: Session, patternNote: String?) -> (
        emotionalState: String,
        themes: [String],
        patientWords: String,
        focusItems: [String],
        patternNote: String?
    ) {
        var emotionalState = "Present and reflecting"
        var themes: [String] = []
        var patientWords = ""
        var focusItems: [String] = []

        for c in session.cards.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            let t = c.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            switch c.cardType {
            case .emotionalState:
                emotionalState = t
            case .mainConcern:
                themes.append(t)
            case .keyEmotion:
                focusItems.append(t)
            case .whatToSay:
                patientWords = patientWords.isEmpty ? t : "\(patientWords) \(t)"
            case .unresolvedThread, .therapyGoal:
                focusItems.append(t)
            case .patternNote, .emotionalRead:
                break
            }
        }

        for i in session.insights {
            if themes.count < 4 {
                themes.append("\(i.theme): \(String(i.text.prefix(160)))")
            }
        }

        if themes.isEmpty { themes = ["What surfaced today"] }
        if patientWords.isEmpty {
            patientWords = firstUserAnchoredQuote(from: session) ?? "I want to show up honestly today."
        }
        if focusItems.isEmpty, let e = session.dominantEmotion {
            focusItems = [e.rawValue]
        }
        if focusItems.isEmpty {
            focusItems = ["What I need from this session"]
        }

        let pw = BriefPatientWordsNormalizer.normalize(
            patientWords,
            userTranscriptLog: session.userTranscriptLog
        )
        return (emotionalState, themes, pw, focusItems, patternNote)
    }

    // MARK: - Weekly brief

    /// Regenerates the weekly brief when there are **2+** completed sessions in the current calendar week (prelude-ios-prd 6.2).
    static func refreshWeeklyBriefIfNeeded(modelContext: ModelContext) async {
        let cal = Calendar.current
        let now = Date()
        guard let interval = cal.dateInterval(of: .weekOfYear, for: now) else { return }
        let weekStart = interval.start

        let thisWeek = SessionStore.completedSessions(in: modelContext, interval: interval)
        guard thisWeek.count >= 2 else { return }

        let newestCompleted = thisWeek.compactMap(\.completedAt).max() ?? now
        if let existing = fetchWeeklyBrief(for: weekStart, in: modelContext) {
            if existing.generatedAt >= newestCompleted, cal.isDate(existing.weekStart, equalTo: weekStart, toGranularity: .weekOfYear) {
                return
            }
            modelContext.delete(existing)
        }

        let bundle = weeklyContextBundle(sessions: thisWeek, cap: maxBundleChars)
        var summary = ""
        var themes: [String] = []
        var dominantResolved = dominantEmotionVote(sessions: thisWeek)
        var suggestions: [String] = []

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let out = await PreludeBriefFoundationModels.synthesizeWeeklyBrief(contextBundle: bundle) {
                summary = trim(out.summary, fallback: "")
                themes = [out.theme1, out.theme2, out.theme3]
                    .map { trim($0, fallback: "") }
                    .filter { !$0.isEmpty }
                let rawEmotion = trim(out.dominantEmotion, fallback: "").lowercased()
                if let label = EmotionLabel.parseCanonicalKey(rawEmotion) {
                    dominantResolved = label
                }
                let shift = trim(out.emotionalShift, fallback: "")
                let sug = trim(out.suggestion, fallback: "")
                if !shift.isEmpty {
                    summary = summary.isEmpty ? shift : "\(summary)\n\n\(shift)"
                }
                if !sug.isEmpty {
                    suggestions = [sug]
                }
            }
        }
        #endif

        if summary.isEmpty {
            summary = templateWeeklySummary(sessions: thisWeek)
        }
        if themes.isEmpty {
            themes = Array(PatternDetector.recurringThemes(from: thisWeek, includeBriefThemes: true).prefix(5))
        }
        if suggestions.isEmpty {
            suggestions = ["What's one thing you want your therapist to understand about how this week felt?"]
        }

        let weekly = WeeklyBrief(
            weekStart: weekStart,
            summary: summary,
            themes: themes,
            dominantEmotion: dominantResolved,
            suggestions: suggestions,
            sessionIds: thisWeek.map { $0.id.uuidString },
            generatedAt: .now
        )
        modelContext.insert(weekly)
    }

    private static func fetchWeeklyBrief(for weekStart: Date, in modelContext: ModelContext) -> WeeklyBrief? {
        let cal = Calendar.current
        var fd = FetchDescriptor<WeeklyBrief>(sortBy: [SortDescriptor(\.generatedAt, order: .reverse)])
        let all = (try? modelContext.fetch(fd)) ?? []
        return all.first { cal.isDate($0.weekStart, equalTo: weekStart, toGranularity: .weekOfYear) }
    }

    private static func weeklyContextBundle(sessions: [Session], cap: Int) -> String {
        var lines: [String] = []
        for s in sessions {
            lines.append("— Session \(s.startedAt.formatted(date: .abbreviated, time: .shortened)) —")
            lines.append("Emotion: \(s.dominantEmotion?.rawValue ?? "unknown")")
            let ut = s.userTranscriptLog.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ut.isEmpty {
                lines.append("USER SPOKE (verbatim):")
                lines.append(String(ut.prefix(2_000)))
            }
            if let b = s.brief {
                lines.append("Brief themes: \(b.themes.joined(separator: "; "))")
                lines.append("Brief emotional state: \(b.emotionalState)")
            }
            for i in s.insights {
                lines.append("Insight (\(i.emotion.rawValue)): \(i.text)")
            }
        }
        var text = lines.joined(separator: "\n")
        if text.count > cap {
            text = String(text.prefix(cap)) + "\n…"
        }
        return text
    }

    private static func dominantEmotionVote(sessions: [Session]) -> EmotionLabel {
        var counts: [EmotionLabel: Int] = [:]
        for s in sessions {
            if let d = s.dominantEmotion, d != .calm {
                counts[d, default: 0] += 1
            }
            for i in s.insights where i.emotion != .calm {
                counts[i.emotion, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? .calm
    }

    private static func templateWeeklySummary(sessions: [Session]) -> String {
        let n = sessions.count
        let top = PatternDetector.recurringThemes(from: sessions, includeBriefThemes: true).prefix(3)
        let t = top.isEmpty ? "the threads you kept returning to" : top.joined(separator: ", ")
        let dom = dominantEmotionVote(sessions: sessions).rawValue
        return """
        This week you made space for \(n) reflections. The through-line that kept surfacing was \(t).

        \(dom.capitalized) showed up most often in what you saved — not as a label, but as a texture running underneath your words.

        If nothing else, you practiced showing up honestly. That counts.
        """
    }
}
