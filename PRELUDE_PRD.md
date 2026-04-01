# Prelude iOS — Product Requirements Document
**On-Device AI Therapy Prep Agent — Apple Intelligence Architecture**
*Living document. Updated as build progresses.*

---

## Document Metadata

| Field | Value |
|---|---|
| Product Name | Prelude iOS |
| Version | 1.0 |
| Platform | iOS 26+ / iPhone with Apple Intelligence |
| Minimum Device | iPhone 15 Pro (A17 Pro) |
| AI Runtime | Foundation Models (on-device, zero API cost) |
| Last Updated | March 31, 2026 (Settings: compact model label, appearance, contact support) |
| Build Status | 🟡 In Progress — Phase 5 polish (presence + accessibility + App Store) |

---

## How we update this document

- **Current focus:** One optional line under this section naming the single active task (clear when idle).
- **In progress:** Prefix a Phase checkbox line with `🔄` and a short parenthetical, e.g. `🔄 (in progress — Foundation Models wiring)`.
- **Done:** Use `[x]`, remove `🔄`, and append **`Files:`** with a comma-separated list of repo paths touched for that item (use a sub-bullet list if long).
- Keep **§12 Build Phases & Task Tracker** aligned with the Phase sections above whenever phase status changes.

**Current focus:** (none)

---

## Build Progress Tracker

### Phase 1 — UI Scaffold ✅
- [x] PRD saved to workspace
- [x] Expo artifact created (`artifacts/prelude`)
- [x] Design system / color tokens defined
- [x] Home Screen — last brief card, **emerging pattern** (streak or recurring theme via `PatternDetector`), **recent check-ins** (up to 2 sessions: dominant emotion or brief tone) — **Files:** Prelude/Prelude/UI/Home/HomeView.swift, Prelude/Prelude/Memory/PatternDetector.swift
- [x] Session Screen (with breathing presence shape)
- [x] Brief Screen (session cards)
- [x] History Screen
- [x] Weekly Brief Screen — **Files:** Prelude/Prelude/UI/Weekly/WeeklyBriefView.swift, Prelude/Prelude/UI/Weekly/EmotionalArcChartView.swift, Prelude/Prelude/Memory/SessionStore.swift
- [x] Settings Screen (disclaimer, crisis resource)
- [x] Tab navigation (NativeTabs with liquid glass)
- [x] Onboarding / Availability States screen — first-launch disclaimer dismisses to **Home** (session only via Begin reflection) — **Files:** Prelude/Prelude/UI/Root/RootView.swift, Prelude/Prelude/UI/Onboarding/OnboardingView.swift

### Phase 2 — Voice System ✅
- [x] STT — Web Speech API on web; native-ready architecture (useVoiceEngine hook)
- [x] Audio capture pipeline — Web Audio API AnalyserNode (web), expo-av metering (native)
- [x] Silence detection — 800ms configurable threshold
- [x] Amplitude reading — drives PresenceShape reactive breathing in real time
- [x] TTS — expo-speech (AVSpeechSynthesizer on iOS, speechSynthesis on web); premium voice selection
- [x] Turn-taking state machine — idle→speaking→listening→processing→speaking loop
- [x] Haptic feedback — session start, end, pause/resume
- [x] Permission denied state — graceful mic access screen
- [x] speakAgent() API — clean imperative bridge for agent to speak opening line

### Phase 3 — Agent System ✅
- [x] LanguageModelSession lifecycle (AgentController) — **Files:** Prelude/Prelude/Agent/AgentController.swift, Prelude/Prelude/Agent/FoundationModelsIntegration.swift
- [x] @Generable AgentDecision struct — **Files:** Prelude/Prelude/Agent/FoundationModelsIntegration.swift, Prelude/Prelude/Agent/AgentDecision.swift
- [x] Conversation phases (warmOpen → openField → excavation → readBack → closing) — **Files:** Prelude/Prelude/Agent/AgentController.swift, Prelude/Prelude/Agent/PreludeAgentPrompts.swift
- [x] Tool implementations (SaveInsight, TagEmotion, GenerateCard, etc.) — **Files:** Prelude/Prelude/Tools/SaveInsightTool.swift, Prelude/Prelude/Tools/TagEmotionTool.swift, Prelude/Prelude/Tools/GenerateCardTool.swift, Prelude/Prelude/Tools/GetPastInsightsTool.swift, Prelude/Prelude/Tools/EndSessionTool.swift, Prelude/Prelude/Tools/ToolRegistry.swift, Prelude/Prelude/Tools/ToolExecutionContext.swift, Prelude/Prelude/Agent/FoundationModelsIntegration.swift
- [x] PreludeAgentPrompts (phase-sensitive system prompts; Foundation `Instructions`) — **Files:** Prelude/Prelude/Agent/PreludeAgentPrompts.swift
- [x] Safety override / crisis detection — **Files:** Prelude/Prelude/App/CrisisDetection.swift, Prelude/Prelude/Voice/VoiceEngine.swift
- [x] Brief generation — **Files:** Prelude/Prelude/Tools/SummarizeSessionTool.swift, Prelude/Prelude/UI/Session/SessionView.swift
- [x] Device-only live agent (no scripted fallback when model eligible) + opening line from model — **Files:** Prelude/Prelude/Agent/AgentController.swift, Prelude/Prelude/Agent/FoundationModelsIntegration.swift, Prelude/Prelude/UI/Session/SessionView.swift, Prelude/Prelude/Voice/VoiceEngine.swift
- [x] Resilient model calls (lenient `action` mapping, tool-free opening `GenerableOpeningUtterance`, tool/text retry, `Logger` + NSError) — **Files:** Prelude/Prelude/Agent/AgentDecision.swift, Prelude/Prelude/Agent/FoundationModelsIntegration.swift
- [x] Xcode / README — **Files:** Prelude/Prelude.xcodeproj/project.pbxproj, Prelude/scripts/generate_xcode_project.py, Prelude/README.md

### Phase 4 — Memory & Persistence ✅
- [x] SwiftData schema (Session, Insight, SessionCard, SessionBrief, WeeklyBrief, EmotionalArc) — **Files:** Prelude/Prelude/Models/SwiftDataModels.swift
- [x] MemoryStore / SessionStore / InsightStore / BriefStore — **Files:** Prelude/Prelude/Memory/MemoryStore.swift (no mock seed), Prelude/Prelude/Memory/SessionStore.swift, Prelude/Prelude/Memory/InsightStore.swift, Prelude/Prelude/Memory/BriefStore.swift, Prelude/scripts/reset_prelude_data.sh (simulator data wipe)
- [x] PatternDetector (cross-session theme analysis; consecutive-session streak for pattern card) — **Files:** Prelude/Prelude/Memory/PatternDetector.swift, Prelude/Prelude/Tools/CheckPatternsTool.swift
- [x] Weekly brief generation (2+ sessions in calendar week gate; on-device FM + template fallback) — **Files:** Prelude/Prelude/Memory/BriefStore.swift, Prelude/Prelude/Memory/PreludeBriefFoundationModels.swift, Prelude/Prelude/UI/Root/RootView.swift
- [x] Session brief synthesis (dedicated brief agent + sanitizer; only “what I need to say” in user voice; FM + fallback; delete brief from detail) — **Files:** Prelude/Prelude/Memory/BriefStore.swift, Prelude/Prelude/Memory/BriefGenerationDraft.swift, Prelude/Prelude/Memory/BriefDraftSanitizer.swift, Prelude/Prelude/Memory/BriefPatientWordsNormalizer.swift, Prelude/Prelude/Memory/PreludeBriefFoundationModels.swift, Prelude/Prelude/Agent/PreludeBriefAgent.swift, Prelude/Prelude/Tools/SummarizeSessionTool.swift, Prelude/Prelude/UI/Session/SessionView.swift, Prelude/Prelude/UI/Brief/BriefDetailView.swift, Prelude/Prelude/Memory/MemoryStore.swift

### Phase 5 — Availability & Polish 🟡
- [x] ModelAvailabilityState guard pattern on every session start — **Files:** Prelude/Prelude/App/ModelAvailabilityState.swift, Prelude/Prelude/App/AppState.swift, Prelude/Prelude/UI/Home/HomeView.swift
- [x] User-facing availability states (warm copy, not error messages) — **Files:** Prelude/Prelude/App/ModelAvailabilityState.swift, Prelude/Prelude/UI/Onboarding/OnboardingView.swift
- [x] Settings — Apple Intelligence row (compact on-device vs scripted label only), Appearance (system / light / dark), medical disclaimer + crisis line + mailto support, Danger “clear all data” — **Files:** Prelude/Prelude/UI/Settings/SettingsView.swift, Prelude/Prelude/App/ModelAvailabilityState.swift, Prelude/Prelude/Memory/MemoryStore.swift, Prelude/Prelude/App/UserSettings.swift, Prelude/Prelude/App/AppState.swift, Prelude/Prelude/UI/Root/RootView.swift, Prelude/Prelude/App/PreludeApp.swift, Prelude/Prelude/App/PreludeHaptics.swift
- [x] Presence — ambient breath + dual reactivity (mic smoothing while listening; TTS `willSpeakRange` envelope while agent speaks; prelude-ios §10.5) — **Files:** Prelude/Prelude/Voice/VoiceEngine.swift, Prelude/Prelude/UI/Session/PresenceShapeView.swift
- [x] Session read-back recap (gathered themes / invitation to add or confirm) + live transcript autoscroll — **Files:** Prelude/Prelude/Agent/PreludeAgentPrompts.swift, Prelude/Prelude/Agent/FoundationModelsIntegration.swift, Prelude/Prelude/Agent/AgentController.swift, Prelude/Prelude/Voice/VoiceEngine.swift, Prelude/Prelude/UI/Session/SessionView.swift, PRELUDE_PRD.md, prelude-ios-prd.md
- [x] Agent continuity + read-back grounding — opening uses **Settings name** + **last completed session** context (brief or transcript clip) + optional **cross-session theme**; read-back prompts include **full `userTranscriptLog`** and recap steering **only in `readBack`** (not late excavation); prompts discourage repetitive “it sounds like…” — **Files:** Prelude/Prelude/Memory/SessionStore.swift, Prelude/Prelude/Agent/FoundationModelsIntegration.swift, Prelude/Prelude/Agent/AgentController.swift, Prelude/Prelude/Agent/PreludeAgentPrompts.swift, PRELUDE_PRD.md
- [ ] Conversation phase coordination (user-grounded) + voice barge-in — **deterministic policy** (`ConversationPhasePolicy`): cumulative user words, substantive turns, saved insights, English wrap/end phrases, validated `readBackSummary` / `endSession`; **host promotion** `excavation` → `readBack` when read-back is allowed and depth/time thresholds are met (~8 min elapsed, word/substantive-turn caps, or 2+ insights); per-turn FM prompt uses **effective phase** for the incoming user line. **No turn-count phase buckets** on device. **Voice interruption (barge-in)**: temporarily disabled in the last stability recovery build to avoid `AVAudioEngine` render/stall issues; will be re-enabled after duplex capture/AEC behavior is locked down. — **Files:** Prelude/Prelude/Agent/ConversationPhasePolicy.swift, Prelude/Prelude/Agent/AgentController.swift, Prelude/Prelude/Agent/FoundationModelsIntegration.swift, Prelude/Prelude/Voice/VoiceEngine.swift, Prelude/Prelude/Voice/SpeechRecognizerService.swift, Prelude/Prelude/UI/Session/SessionView.swift, Prelude/PreludeTests/ConversationPhasePolicyTests.swift, Prelude/scripts/generate_xcode_project.py, Prelude/Prelude.xcodeproj/project.pbxproj, PRELUDE_PRD.md, prelude-ios-prd.md
- [x] TTS — Premium/Enhanced voice asset prefetch on launch + first-session wait sheet (indeterminate; no OS download %) + `usesApplicationAudioSession = false` for TTS vs mic/Siri routing — **Files:** Prelude/Prelude/Voice/TTS.swift, Prelude/Prelude/Voice/VoiceEngine.swift, Prelude/Prelude/App/PreludeApp.swift, Prelude/Prelude/UI/Home/HomeView.swift, Prelude/Prelude/UI/Home/PremiumVoiceWaitSheet.swift, Prelude/PreludeTests/PreludeTTSPrefetchTests.swift, Prelude/scripts/generate_xcode_project.py, Prelude/Prelude.xcodeproj/project.pbxproj
- [ ] Dynamic Type support
- [ ] VoiceOver labels on custom shapes
- [ ] App Store privacy manifest

---

## 1. Product Overview

Prelude is a private, on-device, voice-first reflection agent that helps users prepare for therapy sessions. It guides a natural conversation, extracts emotional themes, and generates a structured personal brief the user can carry into their session.

**What it is:**
- A reflection engine
- A preparation tool
- An insight extractor
- A conversation guide
- A longitudinal memory system

**What it is not:** therapy, diagnosis, or medical advice.

**Why on-device:** Zero API cost = unlimited free use. All conversation data stays on the device — never leaves, never touches a server. This is the core trust proposition.

---

## 2. Core Principles

- **On-device AI only** — Foundation Models, no external API calls
- **Voice first** — the primary interaction is speaking, not typing
- **Agentic, not chatbot** — the agent drives the conversation with purpose
- **Tool-gated memory** — the model never writes to storage directly, only through typed tools
- **Availability-aware** — every code path handles the model being unavailable gracefully
- **Privacy absolute** — no analytics, no telemetry, no network calls during a session
- **Design with intention** — every visual and haptic choice serves the emotional register

---

## 3. Target Devices & Availability

### Supported Devices
| Device | Supported |
|---|---|
| iPhone 15 Pro / Pro Max | ✅ |
| iPhone 16 / 16 Plus / 16 Pro / Pro Max | ✅ |
| iPhone 17 series | ✅ |
| iPhone 15 (non-Pro) | ❌ (A16, no Apple Intelligence) |

### Availability States
```swift
enum ModelAvailabilityState {
    case available
    case notSupported        // device does not support Apple Intelligence
    case disabled            // Apple Intelligence turned off in Settings
    case downloading         // model downloading in background
    case lowPower            // Low Power Mode active
    case thermalThrottle     // device too hot
    case unknown
}
```

**Required guard pattern — use before every session start:**
```swift
let availability = SystemLanguageModel.default.availability

switch availability {
case .available:
    startSession()
case .unavailable(.appleIntelligenceNotEnabled):
    showOnboarding(.enableAppleIntelligence)
case .unavailable(.modelNotReady):
    showOnboarding(.modelDownloading)
default:
    showTemporaryUnavailableState()
}
```

**User-facing states (warm copy, not error messages):**
- **Not supported:** "Prelude requires Apple Intelligence. It's available on iPhone 15 Pro and later."
- **Disabled:** "Turn on Apple Intelligence in Settings → Apple Intelligence & Siri to use Prelude."
- **Downloading:** "Prelude is getting ready — Apple Intelligence is setting up in the background. This only happens once."
- **Low Power:** "Connect to power to start a session — Prelude needs full performance to run."
- **Thermal:** "Your iPhone needs a moment to cool down. Prelude will be ready shortly."

---

## 4. Core Features

### F1 — Live Voice Session
Primary experience. User speaks naturally. Agent listens, reflects, asks, and extracts.

**Session flow:**
```
User taps "Begin" →
Mic activates →
SpeechAnalyzer streams transcript →
Silence detected (800ms threshold) →
Agent processes with LanguageModelSession →
Tool calls execute (saveInsight, tagEmotion, etc.) →
Agent response text generated →
Premium TTS speaks response →
Mic reactivates →
Loop continues until agent or user ends session
```

**Target duration:** 8–12 minutes. Agent guides pacing. No hard cutoff.

**Opening:** When the user has a **name** in Settings and at least one **completed** prior session, the first spoken line may greet by name and briefly acknowledge **last time’s** brief/transcript-relevant thread, then invite what’s present **now** (host injects this context into the opening prompt).

**Read-back (toward session end):** In the **readBack** phase, the agent **recaps aloud** what it gathered (main threads, emotional tone, what seems important to bring to therapy) so the user can judge whether to **add more** or whether it **feels sufficient** before closing and brief generation. The host includes the **full session transcript** in the read-back turn prompt so the on-device model synthesizes the **whole arc**, not only the latest exchange.

### F2 — Agentic Conversation Engine
Tool-based agent loop. Not a chatbot. The agent has a goal: surface what the user needs to bring to therapy. See Section 6 for full architecture.

### F3 — Insight Extraction
During session, agent calls `saveInsight()` silently when it detects emotionally significant content. Never shown mid-session — they accumulate invisibly and become raw material for the session brief.

**Insight dimensions:** Theme, Emotion, Concern, Goal, Conflict

### F4 — Session Brief
Generated after every session. **Dedicated brief agent:** a separate on-device **`LanguageModelSession`** from the live coach with **exactly one tool — `setBriefSection`** (one call per card field). It fills the brief from **`Session.userTranscriptLog`** plus saved insights/cards.

**Voice / synthesis rules (product + enforcement):**
- **Only `what_to_say`** (persisted as `SessionBrief.patientWords`, UI: **WHAT I NEED TO SAY**) should read like the user’s **own line to speak** — one **distilled** first-person carry sentence (about two short sentences max, ~280 characters). **`BriefPatientWordsNormalizer`** caps length and strips full-transcript dumps.
- **All other sections are synthesized therapy-prep copy** — warm first person where natural, but **not** sentences copied from USER SPOKE. That includes the three **weighing** slots (`weighing_on_me`, `secondary_theme`, `tertiary_theme`; UI: **WEIGHING ON ME** ×3): **short summaries of emotional weight**, not verbatim quotes. Cards should **not** repeat the same idea across fields.
- **`pattern_note`**: only when a **cross-session pattern** from **`PatternDetector`** clearly fits this session; otherwise omit. Never paste transcript lines into the pattern card.
- **`emotional_read`**: short **affective read** of the brief the model wrote (tone, tension, hope — not diagnosis), UI: “How this brief reads.”

**Post-processing:** **`BriefDraftSanitizer`** detects transcript-shaped text in non–`what_to_say` fields (substring / turn overlap, length caps) and clears or clamps so the brief stays scannable. Applied in the tool path, draft mapping, one-shot FM fallback, and related **`BriefStore`** assembly.

**Concurrency:** **`PreludeBriefAgent.run`** is **`nonisolated`** so **`respond`** does not execute on the main actor while tools use **`MainActor.run`** to write the **`BriefGenerationDraft`** — avoids the same SwiftData deadlock class as the live session agent.

**Session brief screen:** Under “Session Brief,” the date row includes **`EmotionLabel.resolved(for:)`** (same rules as the weekly arc): one capitalized label plus a small emotion-colored dot beside the date.

**Fallback order:** brief agent → single-shot **`GenerableSessionBriefOut`** (same voice rules in instructions) → card/insight template assembly. **Roughly eight to twelve structured cards** (varies if pattern is omitted) covering:
1. How I showed up today (emotional state)
2. Three things weighing on me (three distinct synthesized lines)
3. Key emotion underneath it
4. What I want to make sure I say
5. An unresolved thread worth exploring
6. Two things I hope for from therapy today (two distinct synthesized lines)
7. Pattern note (if the same recurring **theme** appears across **3+ consecutive** completed sessions — chronological; see prelude-ios-prd Phase 4.6)
8. How this brief reads (affective read), when filled

### F5 — Session History & Emotional Patterns
- Chronological list of past sessions with brief previews
- Emotional arc per session (how tone shifted)
- Pattern detection across sessions
- Weekly brief combining multiple sessions

### F6 — Weekly Brief
**Generation runs only when there are 2+ completed sessions in the current calendar week** (prelude-ios-prd Phase 6.2); otherwise the Weekly tab keeps empty-state copy until the threshold is met. Uses on-device Foundation Models when available, with a deterministic template fallback. Surfaces:
- Recurring themes across the week
- Emotional patterns (what dominated, what shifted)
- One reflection prompt for the upcoming session

### F7 — Memory System
Local only. SwiftData. No iCloud sync in V1.

**Deferred vs original prelude-ios-prd §8 (not v1):** `EmotionLabel.ashamed`; full `EmotionalArc` (opening/closing emotion, ordered sequence, peak timestamp) — app uses a minimal `EmotionalArc.summary` string until a schema pass adds parity.

---

## 5. Foundation Models Architecture

*Implementation pitfalls, retries, and file map: see **§15 Apple Intelligence & Foundation Models — lessons learned**.*

### The Entry Point: LanguageModelSession
```swift
import FoundationModels

let session = LanguageModelSession(
    model: .default,
    tools: [
        SaveInsightTool(),
        TagEmotionTool(),
        GenerateCardTool(),
        SummarizeSessionTool(),
        GetPastInsightsTool(),
        EndSessionTool()
    ],
    instructions: Instructions.sessionAgent
)
```

### Structured Output: @Generable
```swift
@Generable
struct AgentDecision {
    @Guide("The action the agent should take next")
    var action: AgentAction

    @Guide("The text the agent should speak to the user. Warm, calm, and brief.")
    var spokenResponse: String

    @Guide("Internal reasoning — not spoken aloud")
    var reasoning: String
}

@Generable
enum AgentAction: String {
    case respond
    case askQuestion
    case saveInsight
    case reflectBack
    case readBackSummary
    case endSession
}
```

### Prompt Design for a 3B Model
- Be directive, not conversational in system prompts
- Keep the context window lean (rolling summary of last 3–4 exchanges + current turn)
- Constrain output length via @Guide annotations
- Test every prompt on device (not Simulator)

---

## 6. Agent System

### Conversation Phases
```swift
enum ConversationPhase {
    case warmOpen      // ~60s — greeting, set intention
    case openField     // ~3-4min — open question, listen broadly
    case excavation    // ~3-4min — follow the emotional thread
    case readBack      // ~2min — summarize aloud, confirm
    case closing       // ~30s — warm close
}
```

### Tool Registry
```swift
enum ToolRegistry {
    static var allTools: [any Tool] {
        [
            SaveInsightTool(),
            TagEmotionTool(),
            GenerateCardTool(),
            GetPastInsightsTool(),
            CheckPatternsTool(),
            SummarizeSessionTool(),
            EndSessionTool()
        ]
    }
}
```

**Rule:** Model never writes to SwiftData directly. Only tools write to storage.

---

## 7. Voice System

### Frameworks
| Framework | Purpose |
|---|---|
| SpeechAnalyzer | Streaming STT (iOS 18+, replaces SFSpeechRecognizer) |
| AVAudioEngine | Audio capture and processing pipeline |
| AVSpeechSynthesizer | Text-to-speech output |
| CoreHaptics | Haptic feedback for session states |

### TTS — Premium Voice Requirement
**Do not use default AVSpeechSynthesizer voices.** Use Premium system voices:
```swift
private let preferredVoiceIdentifiers = [
    "com.apple.voice.premium.en-US.Zoe",
    "com.apple.voice.premium.en-US.Evan",
    "com.apple.voice.enhanced.en-US.Zoe",
    "com.apple.voice.enhanced.en-US.Evan"
]
```

Speech settings: rate = 0.48, pitchMultiplier = 0.95, volume = 0.9

### Turn-Taking State Machine
```swift
enum VoiceState {
    case idle
    case listening       // mic active, SpeechAnalyzer streaming
    case processing      // agent running, mic muted
    case speaking        // TTS active, mic muted
    case interrupted     // user spoke during agent speech
    case paused          // user tapped pause
    case ended           // session complete
}
```

---

## 8. Memory Schema

```swift
// SwiftData — local only, no iCloud sync in V1

@Model class Session {
    var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var durationSeconds: Int
    var phase: String
    var insights: [Insight]
    var cards: [SessionCard]
    var brief: SessionBrief?
    var emotionalArc: EmotionalArc?
}

@Model class Insight {
    var id: UUID
    var text: String
    var emotion: String     // EmotionLabel raw value
    var theme: String
    var importance: Int     // 1-3
    var sessionId: UUID
    var timestamp: Date
}

@Model class SessionBrief {
    var id: UUID
    var sessionId: UUID
    var generatedAt: Date
    var emotionalState: String
    var themes: [String]
    var patientWords: String
    var focusItems: [String]
    var patternNote: String?
}

enum EmotionLabel: String, Codable, CaseIterable {
    case anxious, sad, angry, confused, hopeful, overwhelmed, frustrated, calm, happy, excited, grieving, reflective
}

enum CardType: String, Codable {
    case emotionalState
    case mainConcern
    case keyEmotion
    case whatToSay
    case unresolvedThread
    case therapyGoal
    case patternNote
}
```

---

## 9. Safety Rules

### What the Agent Must Never Do
- Diagnose any condition
- Suggest medications or treatments
- Interpret symptoms clinically
- Encourage the user to rely on Prelude instead of seeing a therapist
- Continue probing when a user expresses acute distress or hopelessness

### Crisis Detection & Response
**Crisis acknowledgment template (spoken by TTS):**
> "I hear that things feel really heavy right now. I'm not the right support for what you're describing — but support is available. Please reach out to the 988 Suicide and Crisis Lifeline by calling or texting 988. They're there for exactly this."

After this, session ends automatically and the app shows the 988 resource card.

### In-App Disclaimer
Shown on first launch and accessible from Settings:
> "Prelude is a personal reflection and preparation tool. It is not therapy, and it is not a substitute for professional mental health care. If you are in crisis, please contact the 988 Suicide & Crisis Lifeline (call or text 988)."

---

## 10. Design System

### 10.1 The Design Problem
Most AI apps share a visual vocabulary that is instantly recognizable and forgettable: purple-to-blue gradients, pulsing orbs, waveform equalizers, dark backgrounds with glowing UI, robotic grid layouts.

**Prelude must feel like none of those things.**

### 10.2 Design Direction: Warm Instrument
Conceptual anchor: a warm instrument — between a leather-bound journal and a finely tuned musical instrument. Analog in spirit, precise in execution, intimate by design.

**References:**
- Day One — warmth of digital journaling done right
- Things 3 — precision and calm
- Endel — generative atmosphere that serves a mood

**Do NOT reference:**
- Any chatbot UI (OpenAI, Gemini, Claude)
- Calm or Headspace (spa-generic)
- VisionOS spatial computing aesthetics
- Any app that uses "frosted glass" as a personality

### 10.3 Color System

```
// Backgrounds
preludeDepth:     Dark #0F0D0A    Light #FAF7F2
preludeSurface:   Dark #1C1813    Light #F0EBE3
preludeRaised:    Dark #252018    Light #E8E1D6

// Text
preludePrimary:   Dark #F5F0E8    Light #1A1612
preludeSecondary: Dark #9E9485    Light #6B6057
preludeTertiary:  Dark #5C5448    Light #9E9485

// Accent (max 2 uses per screen)
preludeAmber:     #C8873A
preludeSage:      #7A9E7E

// States
preludeCalm:      #4A7C8E  — listening
preludeActive:    #C8873A  — speaking
preludeProcessing:#6B5E4E  — thinking
```

**Color Rules:**
- Never use pure black or pure white
- Accent colors appear on max 2 elements per screen
- Background shifts subtly based on session state (1.5s easeInOut transition)

### 10.4 Typography

Three typefaces only:
1. **New York** — emotionally significant content (brief cards, agent's spoken words)
2. **SF Pro** — UI and informational content (navigation, timestamps, metadata)
3. **SF Mono** — live transcript only (0.7 opacity)

**Type Scale:**
```
preludeHero:       New York 34pt Semibold
preludeTitle:      New York 24pt Regular
preludeCardTitle:  New York 19pt Semibold
preludeCardBody:   New York 16pt Regular
preludeLabel:      SF Pro 13pt Medium
preludeCaption:    SF Pro 11pt Regular
preludeTranscript: SF Mono 14pt Regular (0.7 opacity)
```

**Rules:**
- Line spacing: 1.6× minimum for New York body text
- Never use all-caps except timestamp labels
- Emotional weight communicated through size, not color

### 10.5 Session Screen

**Zone 1 — The Presence (top 60%)**
A large, breathing organic shape. Not a circle, not an orb. A soft, irregular form (layered continuous rects + `TimelineView` ambient breath + drift; full ink-drop `Canvas` path is optional polish).

Behavior:
- Idle/Listening: slow breath (~4s), preludeCalm, 0.15 opacity
- User speaking: responds to amplitude (mic RMS, EMA-smoothed in `VoiceEngine`), breathes faster/more expansively, tints toward preludeActive
- Processing: contracts gently, holds still, preludeProcessing. **No spinner. No "thinking…" text.**
- Agent speaking: expands slowly, holds fuller form, preludeCalm, soft pulse from TTS `willSpeakRangeOfSpeechString` bursts + decay (`AVSpeechSynthesizer` has no public output-level tap)

**Zone 2 — The Ground (bottom 40%)**
- Agent's current text: New York Regular, fades in word-by-word with TTS
- Transcript scroll: SF Mono, low opacity, barely visible; **auto-scrolls** so the latest finalized line and live partial caption stay in view

**Controls:** Pause / End session / Crisis resource (small "?" corner)

**No header. No navigation bar. Full screen. Status bar hidden.**

### 10.6 Liquid Glass Usage
Use for: session cards overlay, modal sheets, history list panel, navigation bar when scrolling
Do NOT use for: presence zone, body text containers, main background

### 10.7 Motion Design
**Principles:** Motion communicates state, not decoration.

**Animation tokens:**
```
preludeSpring:  spring(response: 0.5, dampingFraction: 0.8)
preludeGentle:  easeInOut(0.4)
preludeAmbient: easeInOut(3.8).repeatForever(autoreverse: true)
preludeReveal:  easeOut(0.6)
```

**Card Reveal:** Sequential arrival, 200ms delay per card

### 10.8 Haptic Design
```
sessionBegin:    soft single tap — "I'm listening"
agentSpeaking:   subtle heartbeat while agent speaks
insightSaved:    imperceptible micro-tap — silent confirmation
briefReady:      medium warm double-tap — "here is your brief"
sessionEnd:      gentle fade-out pattern
error:           short soft single — never harsh
```

### 10.9 Screen Specifications

**Home Screen**
- Large centered greeting in New York at 55% from top: "Good morning, [first name]."
- Subtle timestamp below in SF Pro caption
- Single CTA: "Begin Reflection" — New York Semibold, amber color, no border/capsule
- Last session summary below in preludeSecondary
- No tabs, no feature grids, no gamification
- Background: subtle gradient shifting by time of day

**Brief Screen**
- Stacked Liquid Glass cards, swipeable
- Each card: SF Symbol amber icon + SF Pro caption label + New York body
- **User-voice emphasis (amber left border)** applies **only** to **WHAT I NEED TO SAY** (`patientWords` / `what_to_say`). Other cards use standard body styling — they are synthesized prep lines, not transcript excerpts.
- Bottom: "Take this to your session" — copies brief as plain text

**History Screen**
- Vertical timeline
- Each session: date (SF Pro medium) + emotion dot + duration + first theme (New York Regular)
- No charts (emotional trends are in Weekly Brief only)

**Weekly Brief Screen**
- Subtitle: "Week of {date}" from the brief’s `weekStart`
- Emotional arc card (above narrative): dominant emotion per session from `WeeklyBrief.sessionIds`, smooth curve (Catmull–Rom), gradient fill and point labels; "heavier" / "lighter" axis; shown when **two or more** eligible completed sessions exist for that week (up to six points, oldest→newest); **`.calm` is plotted** like any other label; chart container matches Expo `rgba` tint (not Liquid Glass); line/fill use latest-point **tagged** `dominantEmotion` color at Expo opacities; point labels use `EmotionLabel.resolved(for:)` — if `dominantEmotion` is missing or baseline `.calm`, infer from that session’s brief (`emotionalState`, `affectiveAnalysis`, themes) when prose names another `EmotionLabel`; persisted legacy `neutral` decodes as `calm`
- Recurring themes pill row: themed tags from `weeklyBrief.themes` (amber outlines)
- Full-width narrative card: Expo `mainCard` — solid `colors.surface` + border (not Liquid Glass), New York Semibold: "This week."
- Three paragraphs of narrative prose (not bullets)
- "Worth bringing up:" section in amber
- Regenerate button at the bottom: triggers `refreshWeeklyBriefIfNeeded` for the current week

### 10.10 Accessibility
- Dynamic Type on all text
- Minimum 44×44pt tap targets
- VoiceOver labels on all custom shapes
- Reduce Motion: slower, shallower ambient breath — presence remains expressive (product: no flat static ring); optional further dampening elsewhere as needed
- High Contrast: stronger tint overlay on Liquid Glass surfaces
- 988 crisis link always VoiceOver accessible

---

## 11. Swift File Architecture

```
Prelude/
├── App/
│   ├── PreludeApp.swift          — app entry, availability check
│   └── AppState.swift            — global state machine
├── Agent/
│   ├── AgentController.swift     — LanguageModelSession lifecycle, agent loop
│   ├── PreludeAgentPrompts.swift — phase-sensitive prompts + Foundation `Instructions`
│   ├── FoundationModelsIntegration.swift — @Generable decision, live-session Tool adapters, model turn (off MainActor for `respond`)
│   ├── PreludeBriefAgent.swift   — session-brief LanguageModelSession + `setBriefSection` tool only
│   ├── AgentDecision.swift       — @Generable AgentDecision struct
│   └── ConversationPhase.swift   — phase enum and transition logic
├── Tools/
│   ├── ToolRegistry.swift
│   ├── SaveInsightTool.swift
│   ├── TagEmotionTool.swift
│   ├── GenerateCardTool.swift
│   ├── GetPastInsightsTool.swift
│   ├── CheckPatternsTool.swift
│   ├── SummarizeSessionTool.swift
│   └── EndSessionTool.swift
├── Voice/
│   ├── VoiceEngine.swift         — coordinates SpeechRecognizer + TTS
│   ├── SpeechRecognizer.swift    — SpeechAnalyzer wrapper, silence detection
│   ├── TTS.swift                 — AVSpeechSynthesizer, premium voice selection
│   └── VoiceState.swift          — state machine enum
├── Memory/
│   ├── MemoryStore.swift
│   ├── SessionStore.swift
│   ├── InsightStore.swift
│   ├── BriefStore.swift
│   ├── BriefGenerationDraft.swift   — in-memory sections before SessionBrief insert
│   ├── BriefDraftSanitizer.swift    — anti–transcript-paste + caps for non–what_to_say fields
│   ├── BriefPatientWordsNormalizer.swift — cap / excerpt for what_to_say only
│   ├── PreludeBriefFoundationModels.swift — one-shot session/weekly @Generable fallback
│   └── PatternDetector.swift
├── Models/
│   ├── Session.swift
│   ├── Insight.swift
│   ├── SessionCard.swift
│   ├── SessionBrief.swift
│   ├── WeeklyBrief.swift
│   ├── EmotionalArc.swift
│   ├── EmotionLabel.swift
│   ├── EmotionLabel+ResolvedForSession.swift
│   └── CardType.swift
└── UI/
    ├── Home/
    │   ├── HomeView.swift
    │   └── HomeViewModel.swift
    ├── Session/
    │   ├── SessionView.swift
    │   ├── PresenceShape.swift
    │   ├── TranscriptView.swift
    │   └── SessionViewModel.swift
    ├── Brief/
    │   ├── BriefView.swift
    │   └── BriefCard.swift
    ├── History/
    │   ├── HistoryView.swift
    │   └── SessionRow.swift
    ├── Weekly/
    │   ├── WeeklyBriefView.swift
    │   └── EmotionalArcChartView.swift
    └── Settings/
        └── SettingsView.swift
```

---

## 12. Build Phases & Task Tracker

| Phase | Description | Status |
|---|---|---|
| Phase 1 | UI Scaffold — all screens, navigation, design system | ✅ Done |
| Phase 2 | Voice System — STT, TTS, amplitude, turn-taking | ✅ Done |
| Phase 3 | Agent System — LanguageModelSession, tools, prompts | ✅ Done |
| Phase 4 | Memory & Persistence — SwiftData, stores, patterns, weekly + session briefs | ✅ Done |
| Phase 5 | Availability, accessibility, App Store compliance | 🟡 In Progress (availability + Settings + presence reactivity; Dynamic Type / VoiceOver / privacy manifest remain) |

---

## 13. App Store & Privacy Requirements

- No data collection or telemetry
- No network calls during sessions
- Privacy manifest required (PrivacyInfo.xcprivacy)
- Required usage descriptions: NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription
- Age rating: 12+ (mentions of mental health)
- Medical disclaimer must be shown on first launch

---

## 14. Known Risks & Mitigations

| Risk | Mitigation |
|---|---|
| On-device model not available in Simulator | `PreludeModelAvailability.shouldAttemptFoundationModels` is false on Simulator; session uses the scripted fallback. Test Apple Intelligence paths on a physical device with iOS 26+. |
| `SystemLanguageModel` reports available but `respond` still fails | See **§15** (tool-free opening, turn retry without tools, lenient action mapping, console logging). Settings shows a compact live vs scripted label; use Xcode console while debugging. |
| Strict `@Generable` / `action` strings from the model | Use **lenient** mapping to `AgentAction` and require non-empty `spokenResponse`; do not discard a good utterance because `action` ≠ exact `rawValue`. |
| Audio / STT errors (`AURemoteIO`, zero buffer size) | Separate from model availability; tune **AVAudioSession** and capture path (`SpeechRecognizerService`). Model can work while mic pipeline is flaky. |
| Foundation Models API changes before iOS 26 release | Follow WWDC session notes, use availability guards |
| 3B model quality insufficient for emotional nuance | Prompt engineering, constrained output via @Generable |
| SpeechAnalyzer latency in noisy environments | 800ms silence threshold is configurable; fall back to SFSpeechRecognizer |
| Thermal throttling during long sessions | Detect and gracefully pause session |
| User in genuine crisis | Robust crisis detection keywords + immediate 988 routing |
| App Review rejection for mental health content | Medical disclaimer, clear "not therapy" framing in metadata |

---

## 15. Apple Intelligence & Foundation Models — lessons learned

*Engineering notes from shipping **LanguageModelSession** on device (validated March 2026). Aligns with Apple’s documented APIs: `LanguageModelSession(model:tools:instructions:)`, `respond(to:generating:includeSchemaInPrompt:)`, `Prompt { }`, `SystemLanguageModel.default.availability`.*

1. **Availability ≠ success** — `SystemLanguageModel.default.availability == .available` only means the stack *can* run. **`respond` can still throw** or return unusable structured output. Falling back **silently** to a fixed script made it look like “mock mode” while AI was enabled.

2. **Don’t hide failures on device** — When the live model is eligible, **avoid scripted fallbacks** for turns (or users cannot tell model vs script). Surface a short spoken error or retry; log **`NSError` domain/code** via `Logger` (subsystem = bundle id, category `FoundationModels`).

3. **Lenient structured output** — On-device models often emit **non-exact** `action` labels (e.g. synonyms). **`AgentAction.lenient(from:)`** maps synonyms and defaults unknown values to **`respond`** so valid **`spokenResponse`** text is not dropped.

4. **Start simple on the first call** — Registering **many tools** plus a **multi-field** `@Generable` on the **first** `respond` (session opening) was brittle. **Mitigations:** (a) **`GenerableOpeningUtterance`** — single `spokenResponse` field; (b) **tool-free** `LanguageModelSession` for opening; (c) **recreate** the session when switching **no-tools → with-tools** for later turns (`foundationSessionUsesTools` on `AgentController`).

5. **Retry without tools** — If `respond` fails with the full tool registry, **clear the session** and **retry once** with **`tools: []`** so conversation can continue while tool schemas are debugged.

6. **Deployment target** — `@Generable` / macro-generated code required **`IPHONEOS_DEPLOYMENT_TARGET = 26.0`** for this project (see `project.pbxproj` / `generate_xcode_project.py`).

7. **Tool execution vs. where `respond` runs** — SwiftData + `ModelContext` (and **`BriefGenerationDraft`**) must be touched on the **main actor** (`PreludeFMToolRunner`, **`MainActor.run`** in **`SetBriefSectionFMTool`**). If **`LanguageModelSession.respond`** is invoked from **`@MainActor`** while it blocks waiting on the model, tool handlers that need the main queue can **deadlock**. **Mitigation:** **`PreludeFoundationModels.runTurn` / `runOpening`** and **`PreludeBriefAgent.run`** are **`nonisolated`** so **`respond`** runs on the generic executor; only short **`MainActor.run`** blocks mutate SwiftData or the draft.

8. **Naming** — Renamed app prompts to **`PreludeAgentPrompts`** to avoid clashing with **FoundationModels’** `PromptBuilder` / `Prompt` DSL.

9. **PRD / agent workflow** — Cursor rule **`.cursor/rules/prelude-prd-tracker.mdc`** keeps this document as the living tracker (in-progress markers, **Files:** on completion).

### Key files (Foundation Models iteration)

| Area | Paths |
|---|---|
| Session + turns | `Prelude/Prelude/Agent/AgentController.swift`, `Prelude/Prelude/Agent/FoundationModelsIntegration.swift` |
| Decision / actions | `Prelude/Prelude/Agent/AgentDecision.swift` |
| Instructions | `Prelude/Prelude/Agent/PreludeAgentPrompts.swift` |
| Availability / diagnostics | `Prelude/Prelude/App/ModelAvailabilityState.swift`, `Prelude/Prelude/App/AppState.swift` |
| Voice / session UI | `Prelude/Prelude/Voice/VoiceEngine.swift`, `Prelude/Prelude/UI/Session/SessionView.swift` |
| Settings indicator | `Prelude/Prelude/UI/Settings/SettingsView.swift` |
| Tools + context | `Prelude/Prelude/Tools/*.swift` (esp. Save/Tag/Generate/GetPast + `ToolExecutionContext.swift`) |
| Brief synthesis (session + weekly) | `Prelude/Prelude/Memory/BriefStore.swift` (heuristic dominant fallback if tag still weak), `Prelude/Prelude/Memory/BriefGenerationDraft.swift`, `Prelude/Prelude/Memory/BriefDraftSanitizer.swift`, `Prelude/Prelude/Memory/BriefPatientWordsNormalizer.swift`, `Prelude/Prelude/Memory/PreludeBriefFoundationModels.swift` (+ optional `dominantEmotionKey` one-shot), `Prelude/Prelude/Agent/PreludeBriefAgent.swift` (structured ack `dominantEmotionKey` → `Session.dominantEmotion`), `Prelude/Prelude/Models/EmotionLabel.swift` (`parseCanonicalKey`), `Prelude/Prelude/Models/EmotionLabel+ResolvedForSession.swift` (`resolved(for:)`), `Prelude/Prelude/Memory/PatternDetector.swift`, `Prelude/Prelude/Memory/SessionStore.swift`, `Prelude/Prelude/Memory/InsightStore.swift`, `Prelude/Prelude/UI/Brief/BriefDetailView.swift` (date + resolved label header), `Prelude/Prelude/UI/Weekly/WeeklyBriefView.swift`, `Prelude/Prelude/UI/Weekly/EmotionalArcChartView.swift` (weekly arc includes all eligible sessions; calm plotted) |
| Project / docs | `Prelude/Prelude.xcodeproj/project.pbxproj`, `Prelude/scripts/generate_xcode_project.py`, `Prelude/README.md`, `.cursor/rules/prelude-prd-tracker.mdc` |
