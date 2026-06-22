# Talaria — Phase B Handoff (for Claude Code)

Session: 2026-06-21 (continued) · Branch: `feat/phase-b-wiring` (pushed to origin)

## Your mission

Continue Phase B wiring on branch `feat/phase-b-wiring`. Priority order:

1. **Sessions drawer** — wire it to the live Hermes Sessions API: list real
   sessions; tapping one loads its history into the chat and continues that
   thread. **Do this first (UI work before the banner).**
2. **Offline banner** — make the "Hermes host offline" banner reflect the real
   direct-API state instead of relay status. **Do this after Task 1.**

Rules: commit each logical unit with a conventional-commit message; verify the
build (`** BUILD SUCCEEDED **`) before every commit; never hand-edit the
`.xcodeproj` (XcodeGen owns it).

## Already done — do NOT redo

- HUD redesign merged to `main` (`c2069e5`) and pushed.
- **Model selector wired** (commit `173f829`, pushed). Picker populates from the
  host's `/v1/models`; tapping a model calls `switchModel` (a `/model <id>`
  command turn) which applies on the **next session**; picker shows an
  "APPLIES ON NEXT SESSION" hint + a "Start New Session" button. The protocol
  gained `availableModels()` and `switchModel(_:)` (default no-ops in an
  extension; real impls in `SessionsHermesClient`; forwarded by
  `ResilientHermesClient`). `ChatStore` gained `availableModels()` and
  `selectModel(_:)`. Wiring is in `ChatScreen.configureChatSeams()`.

## Task 1 — Sessions drawer (do first)

Shell to fill: `Talaria/Features/Chat/Sessions/SessionsDrawer.swift`
(`SessionsDrawerModel`). Seams: `sessions: [SessionSummary]`, `onSelectSession`
(currently a no-op in `configureChatSeams()`), `onNewChat` (already → clear/new
flow), `onOpenHostSettings` (already routed).

### Server API (Hermes Agent v0.17.0, `http://localhost:8642`, Bearer API key)

Reuse `SessionsHermesClient`'s existing `getJSON` / `makeRequest` plumbing and
its base-URL + API-key providers (wired in `AppContainer.swift`).

- `GET /api/sessions?order=recent&exclude_sources=cron&limit=30`
  -> `{ "sessions": [ ... ], "total": N, "limit": L, "offset": O }`.
  Each session has: `id, source, model, title, started_at, ended_at,
  message_count, preview` (first ~60 chars of first user message),
  `last_active` (epoch seconds), `is_active` (bool), `archived` (bool).
- `GET /api/sessions/{id}/messages` -> full message history. **Inspect the exact
  shape first** (handler `hermes_cli/web_server.py:7350`) and map roles/content
  to the app `Message` model.
- `GET /api/sessions/{id}` -> detail (handler `web_server.py:7322`).

### Plan (~5 files)

1. `SessionsHermesClient.swift`:
   - `listSessions() async throws -> [...]` (GET `/api/sessions`, decode
     `sessions`).
   - `openSession(_ id:) async throws -> Conversation`: set `apiSessionId = id`,
     GET `/api/sessions/{id}/messages`, map -> `Conversation` so new turns
     continue this thread (`ensureSession()` reuses the id).
2. `HermesClientProtocol.swift` + `ResilientHermesClient.swift`: add the two
   methods as requirements (extension defaults), forward through the wrapper to
   `primary` (mirror the existing `availableModels`/`switchModel` pattern).
3. `ChatStore.swift`: `loadSessions()` and `openSession(_ id:)` that swaps the
   displayed `conversation` (mirror `clearConversation()`'s persistence +
   `onConversationChanged?()`).
4. `ChatScreen.configureChatSeams()`: on appear, populate
   `sessionsModel.sessions`; set `onSelectSession` -> `chatStore.openSession`.
   Map fields -> `SessionSummary`: `subtitle = preview` (or "{n} messages"),
   `timeLabel` + group (TODAY / YESTERDAY / EARLIER) from `last_active`,
   `isActive = is_active`. Skip the PINNED group (no server pin concept;
   `grouped()` drops empty groups).

### Acceptance

Drawer lists real sessions grouped by recency; tapping one loads its history and
continues the thread; "New Chat" still starts fresh; `** BUILD SUCCEEDED **`;
one focused commit, pushed.

## Task 2 — Offline banner (after Task 1)

Relay is offline by design and chat goes direct to `localhost:8642`, but the
"Hermes host offline" banner + stale model chip are relay-sourced, so they show
falsely. Drive the banner from the **direct Sessions API** health (the Sessions
client `connectionStatus`, or a `/health` or `/v1/models` probe) instead of
relay status. Trace `hostStore.connectionState`, the banner view in
`ChatScreen.swift`, and host plumbing in `LiveHermesHostService` /
`RelayAPIClient`. Acceptance: when the direct API is reachable, no false offline
banner and the chip shows the live model.

## Backlog — NOT this session

- **Native model endpoints** (Owen prefers these long-term): `GET /api/model/options`
  (list), `GET /api/model/info`, `POST /api/model/set` (switch). Cleaner than the
  current `/v1/models` + `/model`-command path. **Add as an option on the new
  Settings page when it's built** — e.g. a toggle between "command-turn (applies
  next session)" and "native (`/api/model/set`, immediate)".
- **Screen-tour verification**: onboarding/handshake, talk/voice, inbox, settings,
  drawer + selector shells. Confirm whether "GPT-5.5" / "HERMES" are placeholders
  or live bindings.

## Environment / build / conventions

- Repo: `/Users/owenjones/Documents/Claude/Talaria`. XcodeGen — `project.yml` is
  source of truth. Run `xcodegen generate` after any `project.yml` change or
  after adding NEW Swift files, then rebuild. Never hand-edit the `.xcodeproj`.
- Build: `xcodebuild -project Talaria.xcodeproj -scheme Talaria -destination 'id=47F68496-24F9-45D9-93D3-1C778DB6B557' build` (iPhone 17 Pro Max, iOS 26). Require `** BUILD SUCCEEDED **`.
- Deploy: terminate -> install -> launch (installing over a running app only
  foregrounds the OLD process). `idb` keyboard injection does not work in this
  sim — Owen types chat messages manually.
- Runtime: relay OFFLINE; chat direct to `localhost:8642` (Bearer API key from
  app config). Offline banner is expected until Task 2.
- Tooling: Desktop Commander (shell), `gh` (authed as ChronoRixun), `xcodegen`
  2.45.4, xc-all simulator tools.
- Commits: conventional (`feat:`/`fix:`/`refactor:`/`docs:`/`chore:`), one unit
  each, build verified first.
