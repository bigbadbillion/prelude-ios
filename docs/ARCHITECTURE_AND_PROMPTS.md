# Prelude iOS — architecture and agent prompts

This document summarizes the **current** app architecture and **every LLM prompt / instruction surface** so you can analyze behavior and iterate on copy or structure. File paths are repo-relative from the repository root.

---

## 1. Architecture overview

### 1.1 Application shell

| Piece | Role |
|--------|------|
| `Prelude/Prelude/App/PreludeApp.swift` | `@main` entry; SwiftData `modelContainer`; prefetches TTS voice assets. |
| `Prelude/Prelude/App/AppState.swift` | Global UI state (session sheet, brief presentation, crisis sheet, `PreludeModelAvailability`). |
| `Prelude/Prelude/UI/Root/RootView.swift` | Tabs, full-screen `SessionView`, brief sheet, onboarding disclaimer. |

**Persistence:** SwiftData models (`Prelude/Prelude/Models/SwiftDataModels.swift` and related) with `Session`, insights, cards, briefs.

### 1.2 Voice and session loop

| Piece | Role |
|--------|------|
| `Prelude/Prelude/Voice/VoiceEngine.swift` | Orchestrates STT (`SpeechRecognizerService`), TTS (`AVSpeechSynthesizer`), silence detection (~800 ms), barge-in, transcript lines. Exposes `onUserTurnComplete` → async callback that returns agent line + `endSessionAfter`. |
| `Prelude/Prelude/Voice/SpeechRecognizerService.swift` | Speech recognition + amplitude for UI. |
| `Prelude/Prelude/Voice/TTS.swift` | Voice selection / prefetch helpers. |
| `Prelude/Prelude/Agent/AgentController.swift` | **Session agent lifecycle:** `currentPhase`, scripted fallback (`VoiceEngineScript`), tool context box, `respondToUserTurn` → Foundation Models or script. |

**Two conversation drivers:**

1. **Live (device, iOS 26+, Apple Intelligence available):** `LanguageModelSession` via `PreludeFoundationModels` (`FoundationModelsIntegration.swift`).
2. **Scripted fallback:** Fixed lines in `VoiceEngineScript` / `AgentController` (Simulator, low power, model unavailable, etc.).

### 1.3 On-device model availability

`Prelude/Prelude/App/ModelAvailabilityState.swift` — `PreludeModelAvailability.resolve()` for UI copy; `shouldAttemptFoundationModels` gates whether **LanguageModelSession** runs (physical device, iOS 26+, `SystemLanguageModel.default.availability == .available`, not low power / critical thermal).

### 1.4 Conversation phases (app-controlled, not turn-count)

Phases: `warmOpen` → `openField` → `excavation` → `readBack` → `closing` (`Prelude/Prelude/Models/ConversationPhase.swift`).

**Policy:** `Prelude/Prelude/Agent/ConversationPhasePolicy.swift`

- Parses **user utterance signals** (wrap/recap/end/greeting) with deterministic English phrase lists.
- Tracks **user-grounded metrics** (`SessionTurnMetrics`: substantive turns, cumulative words) — not agent reply count.
- Decides when **read-back** and **closing** are allowed (e.g. minimum words/turns before a model `readBackSummary`; closing rules for `endSession` vs user “done”).
- Promotes **`excavation` → `readBack`** when read-back is allowed **and** host depth/time thresholds are met (substantive-turn/word caps, session elapsed ~8 minutes, or multiple saved insights) — not only when the model emits `readBackSummary`.
- `AgentController.applyPhaseAfterAgentTurn` runs **after** each model turn using `rawTranscriptLine` and `modelAction` (with session elapsed time). **`effectivePhaseForIncomingTurn`** projects phase **before** inference so the per-turn prompt matches wrap-up on the same turn as the transition.

### 1.5 Live agent: Foundation Models integration

`Prelude/Prelude/Agent/FoundationModelsIntegration.swift` — `PreludeFoundationModels`:

- **Long-lived `LanguageModelSession`** stored on `AgentController` (`foundationSessionStorage`), recreated when toggling tool vs text-only.
- **Opening:** `runOpening` — **tool-free** session first (`GenerableOpeningUtterance`); on failure, fallback to `GenerableAgentDecision`.
- **Each user turn:** `runTurn` — prompt includes **effective** conversation phase (`AgentController.effectivePhaseForIncomingTurn`), latest user text, structured-output instructions; if effective phase is `readBack`, injects **truncated chronological transcript** (~3800 chars) and recap instructions (and skips the default “always end with a deep question” rule). Retries **with tools**, then **text-only** on failure (resets session).
- **Concurrency:** Model work is **not** on `@MainActor`; tools hop to `MainActor` for SwiftData to avoid deadlock (documented in file).

**Structured output:** `GenerableAgentDecision` → `AgentDecision` (`action`, `spokenResponse`, `reasoning`). `AgentAction` includes `respond`, `askQuestion`, `saveInsight`, `reflectBack`, `readBackSummary`, `endSession` with **lenient** string mapping (`AgentDecision.swift`).

### 1.6 Live agent tools (Foundation Models `Tool` adapters)

Defined in `FoundationModelsIntegration.swift`; executed via `PreludeFMToolRunner` → existing `Prelude/Prelude/Tools/*` types:

| Tool | Purpose |
|------|---------|
| `saveInsight` | Persist insight + emotion label for brief. |
| `tagEmotion` | Session-level emotion tag. |
| `generateCard` | Add structured card toward in-progress brief. |
| `getPastInsights` | Retrieve recent insights summary (cross-session context). |
| `endSession` | Mark session complete when user is done. |

### 1.7 Safety / crisis (non-LLM host path)

`Prelude/Prelude/App/CrisisDetection.swift` — pattern-based detection on user text; `VoiceEngine` invokes `onCrisis` → UI resources sheet. Prompts tell the model not to contradict host crisis guidance.

### 1.8 Memory and briefs

| Piece | Role |
|--------|------|
| `Prelude/Prelude/Memory/SessionStore.swift` | Session CRUD / queries. |
| `Prelude/Prelude/Memory/BriefStore.swift` | **Session brief synthesis** after session: primary **`PreludeBriefAgent`** (tool-based draft), else **`PreludeBriefFoundationModels.synthesizeSessionBrief`** (one-shot), else heuristic/card assembly. Weekly brief refresh. |
| `Prelude/Prelude/Memory/BriefGenerationDraft.swift` | In-memory draft filled by brief agent tools. |
| `Prelude/Prelude/Memory/PreludeBriefFoundationModels.swift` | One-shot FM outputs for session brief fallback + **weekly** brief synthesis. |

**Pattern detection:** Cross-session pattern hints for `pattern_note` (e.g. `PatternDetector` used from `BriefStore`).

---

## 2. Agent prompts and instruction surfaces

Below, **“instructions”** usually means `Instructions { ... }` on `LanguageModelSession` (long-lived system preamble). **“Per-turn / per-task prompt”** means `Prompt { ... }` content for a single `respond` call.

### 2.1 Live session — long-lived session instructions

**File:** `Prelude/Prelude/Agent/PreludeAgentPrompts.swift`

| API | What it does |
|-----|----------------|
| `foundationSessionInstructionsString()` | Full string: Prelude role (not therapist), **TTS-oriented** `spokenResponse`, default **brief connect + one open question**, rotate away from repetitive “it sounds like…”, **readBack** behavior (use full transcript host provides; `readBackSummary`), tools (`saveInsight`, `tagEmotion`, `getPastInsights`, `generateCard`, `endSession`), phase flow, crisis/safety line. |
| `foundationInstructions()` (iOS 26+) | Wraps the same string as `Instructions` for `LanguageModelSession` constructor. |

**Used by:** `PreludeFoundationModels.languageModelSession` when creating the live session (`FoundationModelsIntegration.swift`).

### 2.2 Live session — phase-specific string (logging / non-FM path)

**File:** `Prelude/Prelude/Agent/PreludeAgentPrompts.swift`

| API | What it does |
|-----|----------------|
| `systemInstructions(for phase: ConversationPhase)` | Shorter string form: role, phase name, brief spoken style, one reflective question after substantive share, optional hints for **readBack** (recap + invite confirm) and **closing** (warm, brief). |

**Note:** As of this writing, this method appears **only** in `PreludeAgentPrompts.swift` (not wired into `LanguageModelSession`). It is useful for documentation, tests, or future dual-path prompts.

### 2.3 Opening turn — per-task prompt (no tools)

**File:** `Prelude/Prelude/Agent/FoundationModelsIntegration.swift` — `runOpening`

Built dynamically as `openingInstructions`:

- Session just started; user has not spoken; phase `warmOpen`.
- Ask for **only** `spokenResponse` (warm, brief, **one open question**), one or two sentences for TTS.
- Optional: **preferred first name** from `UserSettings`.
- Optional: **previous session opening context** from `SessionStore.previousSessionOpeningContext` — continuity, paraphrase, invite what’s present now.

**Structured output:** Primary `GenerableOpeningUtterance`; fallback prompt adds explicit `action` / `reasoning` / `GenerableAgentDecision`.

**Guides in schema:** `GenerableOpeningUtterance` and `GenerableAgentDecision` carry `@Guide` text that shapes the opening (`FoundationModelsIntegration.swift`).

### 2.4 Live user turns — per-turn prompt

**File:** `Prelude/Prelude/Agent/FoundationModelsIntegration.swift` — `runTurn`

Appends to the prompt (in order):

1. `Current conversation phase: <effectivePhase>.` from `effectivePhaseForIncomingTurn` (includes latest user line in metrics; aligns wrap-up with read-back on the transition turn).
2. `User said (latest turn): <userUtteranceForModel>` (may include barge-in preamble for the model).
3. Structured output reminder: `action`, `spokenResponse`, `reasoning`; use tools when helpful.
4. If **read-back steer** (effective phase is `readBack`): inject **chronological session transcript** (truncated) + paragraph instructing **whole-arc** synthesis, prefer `readBackSummary`; do not push a separate deep exploratory question.
5. Else if effective phase **closing**: short note — warm gratitude, no new deep probes unless user still sharing.
6. Else: substantive shares → **end with one gentle open question** (unless minimal greeting, safety/crisis, or clear read-back/closing as appropriate).

Stored `currentPhase` is updated **after** the model returns (`recordUserTurnMetricsOnly` then `applyPhaseAfterAgentTurn` with the same policy + `sessionElapsedSeconds`).

### 2.5 Brief writer agent — instructions + prompt

**File:** `Prelude/Prelude/Agent/PreludeBriefAgent.swift`

| Piece | Content summary |
|--------|-------------------|
| **Session `Instructions`** (`instructionsString`) | Role: **session-brief writer** (not live coach). Therapy-prep **worksheet** from USER SPOKE + saved material. Critical **voice rule:** only **`what_to_say`** may echo user voice; all other sections **synthesized**, no transcript copying. Section keys include **three** weighing lines (`weighing_on_me`, `secondary_theme`, `tertiary_theme`) and **two** hope lines (`therapy_goal`, `therapy_goal_2`), plus `emotional_state`, `key_emotion`, `what_to_say`, `unresolved_thread`, `pattern_note`, `emotional_read`. De-duplication; no invented crises. Finish with structured completion. |
| **Tool `setBriefSection`** | Per-section writer; `@Guide` on `section` and `text` describes keys and sanitization expectations. |
| **Structured completion** `GenerableBriefAgentAck` | `status` = "done"; optional `dominantEmotionKey` for session. |
| **`Prompt`** | `=== MATERIAL ===` + context bundle; optional `=== CROSS-SESSION PATTERN ===`; `=== TASK ===` listing required sections; optional `pattern_note` only when the cross-session pattern fits. |

**Tool implementation:** Normalizes/sanitizes via `BriefPatientWordsNormalizer` / `BriefDraftSanitizer` to reduce verbatim transcript bleed.

### 2.6 Session brief — one-shot fallback (no tools)

**File:** `Prelude/Prelude/Memory/PreludeBriefFoundationModels.swift` — `synthesizeSessionBrief`

| Piece | Content summary |
|--------|-------------------|
| **`Instructions`** | Fallback brief writer: only **patientWords** may echo user in one line; other fields synthesized; `patternNote` empty unless pattern in prompt fits; no clinical diagnosis; `dominantEmotionKey` when confident. |
| **`Prompt`** | Context bundle + optional cross-session pattern line + “Produce the structured brief.” |

**Output schema:** `GenerableSessionBriefOut` with per-field `@Guide` strings (emotional state, three theme lines, patient words, four focus slots mapped to key emotion / unresolved thread / two hopes, pattern, emotion key).

### 2.7 Weekly brief — one-shot

**File:** `Prelude/Prelude/Memory/PreludeBriefFoundationModels.swift` — `synthesizeWeeklyBrief`

| Piece | Content summary |
|--------|-------------------|
| **`Instructions`** | Prelude weekly summary from provided session data only; no invention; three short paragraphs; emotional dominance/shift when supported; empty unused theme fields. |
| **`Prompt`** | Week data bundle + “Write the structured weekly brief from this data only.” |

**Output schema:** `GenerableWeeklyBriefOut` (summary paragraphs, themes, dominant emotion, emotional shift, suggestion).

---

## 3. Quick reference: where to edit what

| Goal | Primary location |
|------|------------------|
| Live coach persona, tools, read-back rules (session `Instructions`) | `PreludeAgentPrompts.foundationSessionInstructionsString()` |
| Per-turn steering (transcript injection, closing note) | `PreludeFoundationModels.runTurn` prompt builder |
| Opening greeting + continuity | `PreludeFoundationModels.runOpening` `openingInstructions` |
| Brief card field semantics + anti-copying rules | `PreludeBriefAgent.instructionsString` + `SetBriefSectionFMTool` description/guides |
| Weekly copy constraints | `PreludeBriefFoundationModels.synthesizeWeeklyBrief` instructions |
| Phase transitions (when read-back/closing allowed) | `ConversationPhasePolicy.swift` |
| Tool behavior (what gets saved) | `Prelude/Prelude/Tools/*.swift` + `PreludeFMToolRunner` |

---

## 4. Related PRD / product docs

- Progress tracker: `PRELUDE_PRD.md`
- Product spec (canonical where they differ): `prelude-ios-prd.md`

This file is a **snapshot** of the codebase; when you change prompts or flow, update it in the same change set if you rely on it staying accurate.
