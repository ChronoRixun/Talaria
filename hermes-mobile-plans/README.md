# Hermes Mobile Planning Pack

This planning pack now covers both:
- Phase 1: the native iOS frontend MVP shell
- Phase 2+: the full Hermes-compatible buildout, including backend relay, push, background sync, capability wiring, and continuation guidance for Claude Code or Codex

Folder:
- `/Users/dylan-mac-mini/Documents/hermes-mobile-plans/`

Recommended reading order:
1. `0-start-here.md`
2. `18-build-sequence-and-execution-guide.md`
3. `11-agent-handoff-prompt.md`
4. `00-project-brief.md`
5. `02-app-architecture.md`
6. then read the stage-specific docs referenced by the execution guide

Files:
- `00-mega-handoff-prompt.md` — single copy-paste prompt to hand Claude Code or Codex along with the planning pack
- `0-start-here.md` — first file for Claude Code / Codex to read before anything else
- `00-project-brief.md` — expanded project brief for full app vision
- `01-frontend-mvp-implementation-plan.md` — detailed frontend MVP implementation plan
- `02-app-architecture.md` — client/backend/relay architecture and dependency design
- `03-ui-ux-spec.md` — screen-by-screen frontend UX spec
- `04-data-models-and-service-contracts.md` — models, protocols, and service contracts
- `05-permissions-capabilities.md` — permissions and capability policy guidance
- `06-voice-talk-mode-spec.md` — Talk Mode frontend spec
- `07-persistence-sync-notifications-spec.md` — persistence, sync, notifications, and background execution plan
- `08-backend-integration-seams.md` — exact seams for future Hermes/backend integration
- `09-testing-qa-checklist.md` — QA and acceptance checklist
- `10-file-structure-recommendation.md` — recommended Swift project layout
- `11-agent-handoff-prompt.md` — updated handoff prompt for Claude Code / Codex continuation
- `12-provider-and-platform-research.md` — provider recommendations and relay hosting tradeoffs
- `13-ios26-reference-notes.md` — Apple docs notes relevant to iOS 26-era implementation
- `14-hermes-compatibility-and-tooling.md` — Hermes framework compatibility guidance
- `15-complete-buildout-roadmap.md` — staged roadmap from MVP to full product
- `16-self-hosting-and-deployment-strategy.md` — hosted vs self-host strategy and provider-neutral deployment guidance
- `17-relay-backend-implementation-plan.md` — step-by-step plan for building the relay/backend service
- `18-build-sequence-and-execution-guide.md` — master execution order and doc-by-doc build schedule
- `19-api-contracts-openapi-draft.md` — concrete first-pass relay API contract draft
- `20-relational-schema-draft.md` — practical first-pass Postgres schema draft for the relay

What changed in this revision:
- added provider recommendations, including Fly.io, Render, and Cloudflare tradeoffs
- added Apple documentation references relevant as of March 2026
- expanded background execution guidance for iOS 26-era APIs and constraints
- added Hermes-specific backend compatibility guidance
- upgraded the planning pack from frontend-only into a continuation-ready full buildout reference set

Primary recommendation:
- keep Hermes runtime off-device
- use the iOS app as a native UI + device capability endpoint
- use a lightweight backend relay for auth, ephemeral keys, APNs, inbox events, and sync
- prefer direct app-to-OpenAI realtime voice for foreground Talk Mode, with backend-issued ephemeral credentials
