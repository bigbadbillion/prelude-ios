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
| Last Updated | March 19, 2026 |
| Build Status | 🟡 In Progress |

---

## Build Progress Tracker

### Phase 1 — UI Scaffold ✅
- [x] PRD saved to workspace
- [x] Expo artifact created (`artifacts/prelude`)
- [x] Design system / color tokens defined
- [x] Home Screen
- [x] Session Screen (with breathing presence shape)
- [x] Brief Screen (session cards)
- [x] History Screen
- [x] Weekly Brief Screen
- [x] Settings Screen (disclaimer, crisis resource)
- [x] Tab navigation (NativeTabs with liquid glass)
- [x] Onboarding / Availability States screen

### Phase 2 — Voice System 🔲
- [ ] SpeechAnalyzer integration (streaming STT, iOS 18+)
- [ ] AVAudioEngine audio capture pipeline
- [ ] Silence detection (800ms threshold)
- [ ] Amplitude reading for presence shape animation
- [ ] TTS (AVSpeechSynthesizer, premium voice selection)
- [ ] Turn-taking state machine
- [ ] Haptic engine (CoreHaptics)

### Phase 3 — Agent System 🔲
- [ ] LanguageModelSession lifecycle (AgentController)
- [ ] @Generable AgentDecision struct
- [ ] Conversation phases (warmOpen → openField → excavation → readBack → closing)
- [ ] Tool implementations (SaveInsight, TagEmotion, GenerateCard, etc.)
- [ ] PromptBuilder (phase-sensitive system prompts)
- [ ] Safety override / crisis detection
- [ ] Brief generation

### Phase 4 — Memory & Persistence 🔲
- [ ] SwiftData schema (Session, Insight, SessionCard, SessionBrief, WeeklyBrief, EmotionalArc)
- [ ] MemoryStore / SessionStore / InsightStore / BriefStore
- [ ] PatternDetector (cross-session theme analysis)
- [ ] Weekly brief generation

### Phase 5 — Availability & Polish 🔲
- [ ] ModelAvailabilityState guard pattern on every session start
- [ ] User-facing availability states (warm copy, not error messages)
- [ ] Reduce Motion accessibility support
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

### F2 — Agentic Conversation Engine
Tool-based agent loop. Not a chatbot. The agent has a goal: surface what the user needs to bring to therapy. See Section 6 for full architecture.

### F3 — Insight Extraction
During session, agent calls `saveInsight()` silently when it detects emotionally significant content. Never shown mid-session — they accumulate invisibly and become raw material for the session brief.

**Insight dimensions:** Theme, Emotion, Concern, Goal, Conflict

### F4 — Session Brief
Five to seven structured cards covering:
1. How I showed up today (emotional state)
2. The thing that's really weighing on me
3. Key emotion underneath it
4. What I want to make sure I say
5. An unresolved thread worth exploring
6. What I'm hoping therapy helps with today
7. Pattern note (if recurring theme detected across 3+ sessions)

### F5 — Session History & Emotional Patterns
- Chronological list of past sessions with brief previews
- Emotional arc per session (how tone shifted)
- Pattern detection across sessions
- Weekly brief combining multiple sessions

### F6 — Weekly Brief
Generated after the week's sessions. Surfaces:
- Recurring themes across the week
- Emotional patterns
- One reflection prompt for the upcoming session

### F7 — Memory System
Local only. SwiftData. No iCloud sync in V1.

---

## 5. Foundation Models Architecture

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
    case anxious, sad, angry, confused, hopeful, overwhelmed, frustrated, neutral, grieving
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
A large, breathing organic shape. Not a circle, not an orb. A soft, irregular form.

Behavior:
- Idle/Listening: slow breath (~4s), preludeCalm, 0.15 opacity
- User speaking: responds to amplitude, breathes faster/more expansively, tints toward preludeActive
- Processing: contracts gently, holds still, preludeProcessing. **No spinner. No "thinking…" text.**
- Agent speaking: expands slowly, holds fuller form, preludeCalm, soft pulse

**Zone 2 — The Ground (bottom 40%)**
- Agent's current text: New York Regular, fades in word-by-word with TTS
- Transcript scroll: SF Mono, low opacity, barely visible

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
- User's own preserved words: New York Italic, thin amber left border
- Bottom: "Take this to your session" — copies brief as plain text

**History Screen**
- Vertical timeline
- Each session: date (SF Pro medium) + emotion dot + duration + first theme (New York Regular)
- No charts (emotional trends are in Weekly Brief only)

**Weekly Brief Screen**
- Full-width card, New York Semibold: "This week."
- Three paragraphs of narrative prose (not bullets)
- "Worth bringing up:" section in amber

### 10.10 Accessibility
- Dynamic Type on all text
- Minimum 44×44pt tap targets
- VoiceOver labels on all custom shapes
- Reduce Motion: breathing shape → simple static ring with fade transitions
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
│   ├── PromptBuilder.swift       — phase-sensitive system prompts
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
│   └── PatternDetector.swift
├── Models/
│   ├── Session.swift
│   ├── Insight.swift
│   ├── SessionCard.swift
│   ├── SessionBrief.swift
│   ├── WeeklyBrief.swift
│   ├── EmotionalArc.swift
│   ├── EmotionLabel.swift
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
    │   └── WeeklyBriefView.swift
    └── Settings/
        └── SettingsView.swift
```

---

## 12. Build Phases & Task Tracker

| Phase | Description | Status |
|---|---|---|
| Phase 1 | UI Scaffold — all screens, navigation, design system | 🟡 In Progress |
| Phase 2 | Voice System — STT, TTS, amplitude, turn-taking | 🔲 Not Started |
| Phase 3 | Agent System — LanguageModelSession, tools, prompts | 🔲 Not Started |
| Phase 4 | Memory & Persistence — SwiftData models | 🔲 Not Started |
| Phase 5 | Availability, accessibility, App Store compliance | 🔲 Not Started |

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
| Foundation Models API changes before iOS 26 release | Follow WWDC session notes, use availability guards |
| 3B model quality insufficient for emotional nuance | Prompt engineering, constrained output via @Generable |
| SpeechAnalyzer latency in noisy environments | 800ms silence threshold is configurable; fall back to SFSpeechRecognizer |
| Thermal throttling during long sessions | Detect and gracefully pause session |
| User in genuine crisis | Robust crisis detection keywords + immediate 988 routing |
| App Review rejection for mental health content | Medical disclaimer, clear "not therapy" framing in metadata |
