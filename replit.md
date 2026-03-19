# Workspace

## Overview

pnpm workspace monorepo using TypeScript. Contains the Prelude iOS therapy prep app (Expo) and supporting infrastructure.

## Products

### Prelude (artifacts/prelude)
An on-device AI therapy preparation agent for iOS. Powered by Apple Intelligence (Foundation Models). Voice-first, private, no external API calls.

Full PRD: `PRELUDE_PRD.md` at workspace root.

**Current Phase:** Phase 1 — UI Scaffold complete. Phases 2–5 (Voice, Agent, Memory, Polish) to be built next.

**Screens:**
- Home (Begin Reflection)
- Session (Presence Shape + voice interaction)
- Brief (stacked session cards)
- History (session timeline)
- Weekly Brief (narrative weekly summary)
- Settings (profile, privacy, crisis resource)
- Onboarding/Disclaimer

**Design System:** Warm instrument aesthetic. Earth tones — amber (#C8873A), sage (#7A9E7E), warm near-blacks/whites. New York serif for emotional content, SF Pro for UI. See `constants/colors.ts` and `constants/typography.ts`.

## Stack

- **Monorepo tool**: pnpm workspaces
- **Node.js version**: 24
- **Package manager**: pnpm
- **TypeScript version**: 5.9
- **API framework**: Express 5
- **Database**: PostgreSQL + Drizzle ORM
- **Validation**: Zod (`zod/v4`), `drizzle-zod`
- **API codegen**: Orval (from OpenAPI spec)
- **Build**: esbuild (CJS bundle)
- **Mobile**: Expo SDK 54, Expo Router, React Native

## Structure

```text
/
├── artifacts/
│   ├── api-server/         # Express API server
│   ├── mockup-sandbox/     # Design mockup sandbox
│   └── prelude/            # Prelude Expo app (PRIMARY)
│       ├── app/            # Expo Router screens
│       │   ├── (tabs)/     # Tab screens (Home, History, Weekly, Settings)
│       │   ├── session.tsx # Live voice session screen
│       │   ├── brief/[id]  # Session brief screen
│       │   └── onboarding  # First-launch disclaimer
│       ├── components/     # Reusable components
│       │   ├── PresenceShape.tsx   # Breathing organic shape (session)
│       │   ├── BriefCard.tsx       # Session brief cards
│       │   └── SessionRow.tsx      # History list rows
│       ├── context/
│       │   └── AppContext.tsx      # Global state (sessions, voice state)
│       └── constants/
│           ├── colors.ts           # Prelude color palette
│           └── typography.ts       # Type scale
├── lib/                    # Shared libraries
│   ├── api-spec/           # OpenAPI spec + Orval codegen config
│   ├── api-client-react/   # Generated React Query hooks
│   ├── api-zod/            # Generated Zod schemas from OpenAPI
│   └── db/                 # Drizzle ORM schema + DB connection
├── PRELUDE_PRD.md          # Full Product Requirements Document
└── scripts/                # Utility scripts
```

## Prelude Build Phases

| Phase | Description | Status |
|---|---|---|
| 1 | UI Scaffold — all screens, navigation, design system | ✅ Complete |
| 2 | Voice System — STT, TTS, amplitude, turn-taking | 🔲 Not Started |
| 3 | Agent System — Foundation Models, tools, prompts | 🔲 Not Started |
| 4 | Memory & Persistence — SwiftData models | 🔲 Not Started |
| 5 | Availability, accessibility, App Store compliance | 🔲 Not Started |

## TypeScript & Composite Projects

Every package extends `tsconfig.base.json` which sets `composite: true`. The root `tsconfig.json` lists all packages as project references.

- **Always typecheck from the root** — run `pnpm run typecheck`
- **`emitDeclarationOnly`** — we only emit `.d.ts` files during typecheck
- **Project references** — when package A depends on package B, A's `tsconfig.json` must list B in `references`

## Root Scripts

- `pnpm run build` — runs `typecheck` first, then recursively runs `build`
- `pnpm run typecheck` — runs `tsc --build --emitDeclarationOnly`
