# Hermes Mobile Agent Handoff Prompt

Use this after the initial frontend generation pass, when bringing Claude Code or Codex into the repo for continuation.

---

Continue building Hermes Mobile, a native SwiftUI iPhone app for a persistent Hermes agent system.

Important context:
- The first-generation frontend MVP may already exist in the repo.
- Your job is to inspect the existing codebase, preserve good structure where possible, and continue the app toward a production-ready architecture.
- Do not throw away working UI unless a targeted refactor is clearly justified.
- The plan files in `/Users/dylan-mac-mini/Documents/hermes-mobile-plans/` are the source of truth for product and architecture direction.

Read these files before coding:
- `00-project-brief.md`
- `01-frontend-mvp-implementation-plan.md`
- `02-app-architecture.md`
- `03-ui-ux-spec.md`
- `04-data-models-and-service-contracts.md`
- `05-permissions-capabilities.md`
- `06-voice-talk-mode-spec.md`
- `07-persistence-sync-notifications-spec.md`
- `08-backend-integration-seams.md`
- `09-testing-qa-checklist.md`
- `10-file-structure-recommendation.md`
- `12-provider-and-platform-research.md`
- `13-ios26-reference-notes.md`
- `14-hermes-compatibility-and-tooling.md`
- `15-complete-buildout-roadmap.md`

Execution instructions:
1. Inspect the current Swift project structure and summarize what already exists.
2. Reconcile the existing codebase with the planning docs instead of rewriting blindly.
3. Preserve UI polish already generated if it is sound.
4. Normalize the architecture around protocol-based services and a clear app container if that is missing.
5. Ensure the frontend MVP is compileable and continuation-ready.
6. Add or refine TODO seams for:
   - live Hermes chat transport
   - device registration/auth bootstrap
   - APNs token registration and inbox sync
   - OpenAI Realtime Talk Mode via backend-issued ephemeral credentials
   - native capability services for Location, Health, Notifications, Camera, and Photos
7. If the frontend MVP is already solid, begin phase 2 by adding backend-facing config and service stubs without breaking the app.

Key product/architecture constraints:
- Hermes runtime should stay off-device
- iOS app is the native UI + device capability client
- relay/backend handles auth, push, inbox, sync, and ephemeral session issuance
- foreground Talk Mode should prefer direct app-to-OpenAI Realtime using ephemeral backend-issued credentials
- background execution must follow iOS constraints and must not assume always-on runtime inside the app

Provider guidance:
- Fly.io or Render are the strongest default relay hosting choices
- Cloudflare can be used selectively for edge/realtime patterns, but do not force the whole architecture into edge-only primitives if it complicates Hermes runtime compatibility

Code expectations:
- compileable app
- SwiftUI-native structure
- no secret keys in app code
- no fake enterprise architecture
- no backend credentials required for local compile
- clean, continuation-ready service boundaries

At the end of your work, summarize:
- what was preserved
- what was refactored
- what remains mocked
- which files now form the primary integration seams for the full buildout

---
