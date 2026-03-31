# Hermes Mobile Mega Handoff Prompt

Use this as the single prompt to give Claude Code or Codex when handing over the repo plus this planning pack.

---

You are continuing development of Hermes Mobile, a native SwiftUI iPhone app and companion relay/backend for a persistent Hermes agent system.

Important context:
- A first-pass frontend generation may already exist in the repo.
- Your job is not to blindly regenerate everything.
- You must inspect the current codebase first, preserve good work, and continue the buildout in staged, production-minded steps.
- The planning pack at `/Users/dylan-mac-mini/Documents/hermes-mobile-plans/` is the source of truth.

Absolute first step:
Read these files in this exact order:
1. `0-start-here.md`
2. `18-build-sequence-and-execution-guide.md`
3. `11-agent-handoff-prompt.md`
4. `00-project-brief.md`
5. `02-app-architecture.md`

Then follow the stage-specific document references from `18-build-sequence-and-execution-guide.md`.

Core architecture constraints:
- Hermes runtime stays off-device.
- The iOS app is a native client, UI shell, and device capability endpoint.
- A relay/backend handles auth, APNs, inbox, sync, and ephemeral realtime session issuance.
- Foreground Talk Mode should use backend-issued client-safe credentials for OpenAI Realtime.
- The backend must remain provider-neutral even if first-party deployment targets Fly.io.
- Self-hosting should work via Docker-first deployment.

Execution rules:
1. Inspect the existing repo before making structural decisions.
2. Do not discard working SwiftUI UI unless a targeted refactor is clearly justified.
3. Keep the app compileable after each stage.
4. Work in stages, not one giant rewrite.
5. Prefer protocol-based service boundaries and explicit dependency injection.
6. Avoid overengineering.
7. Do not place backend logic directly inside views.
8. Do not put provider root secrets in the iOS app.
9. Preserve mock fallbacks where useful during staged integration.
10. Summarize progress and remaining seams at the end of each stage.

What this planning pack includes:
- frontend MVP plan
- UI/UX screen spec
- data models and service contracts
- permissions/capabilities guidance
- Talk Mode guidance
- persistence/sync/notification strategy
- backend integration seams
- provider/platform research
- iOS 26 platform constraints notes
- Hermes compatibility guidance
- full staged roadmap
- self-hosting and deployment strategy
- relay backend implementation plan
- API contract draft
- relational schema draft

Recommended working order:
- Stage 0: inspect and reconcile existing frontend
- Stage 1: finish/normalize frontend MVP
- Stage 2: validate integration seams
- Stage 3: scaffold relay and deployment foundation
- Stage 4: implement device/session/inbox APIs
- Stage 5: wire live chat transport
- Stage 6: wire APNs + inbox end-to-end
- Stage 7: wire live Talk Mode
- Stage 8: wire native capabilities
- Stage 9: background-safe sync and polish
- Stage 10: system integration surfaces
- Stage 11: production hardening

If the frontend shell is already good:
- preserve it
- normalize architecture only where necessary
- move quickly into phase 2 relay + live-service work

If the frontend shell is weak or inconsistent:
- repair it using the planning pack
- do not over-refactor aesthetic details that are already acceptable

Backend choice guidance:
- preferred first-party managed target: Fly.io
- simpler hosted alternative: Render
- self-host default: Docker Compose
- do not hardwire the backend to one hosting provider

Expected outputs from you:
- a compileable SwiftUI app
- a provider-neutral relay/backend scaffold or implementation
- clean service seams between app and backend
- TODOs or follow-up notes only where genuinely necessary
- concise status reports after each major stage

At the end of your current working session, report:
1. what you inspected
2. what you preserved
3. what you changed
4. what now compiles or runs
5. what remains mocked
6. what the next correct stage is according to `18-build-sequence-and-execution-guide.md`

Do not skip the planning docs. Start with `0-start-here.md` now.

---
