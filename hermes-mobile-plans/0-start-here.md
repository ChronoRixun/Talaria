# START HERE — Hermes Mobile Build Pack

This is the first file Claude Code or Codex should read.

Goal:
Use this planning pack to continue Hermes Mobile from generated frontend code into a complete app + relay buildout in the correct order.

Primary rule:
Do not try to build everything in one pass. Work in stages.

## First documents to read, in order
1. `18-build-sequence-and-execution-guide.md`
2. `11-agent-handoff-prompt.md`
3. `00-project-brief.md`
4. `02-app-architecture.md`
5. then read the stage-specific docs referenced by `18-build-sequence-and-execution-guide.md`

## What this pack contains
- frontend MVP plan
- app architecture
- screen/UI spec
- service contracts
- permission/privacy guidance
- persistence/sync/background guidance
- provider/deployment recommendations
- Hermes compatibility guidance
- self-hosting strategy
- relay backend implementation plan
- API contract draft
- relational schema draft
- master build sequence

## How to use this pack
1. Inspect the existing repo first.
2. Reconcile generated code with the plan instead of rewriting blindly.
3. Follow `18-build-sequence-and-execution-guide.md` stage by stage.
4. At each stage, read only the relevant docs it references.
5. Keep the app compileable after each step.
6. Preserve good UI and only refactor where clearly justified.

## Important architecture constraints
- Hermes runtime stays off-device
- iOS app is the native client + capability endpoint
- relay/backend handles auth, APNs, inbox, sync, and ephemeral realtime issuance
- foreground Talk Mode should use backend-issued client-safe credentials
- backend architecture should remain provider-neutral even if first-party deployment uses Fly.io
- self-hosting should work via Docker-first deployment

## If you only read one implementation doc after this
Read:
- `18-build-sequence-and-execution-guide.md`

## Completion check
This planning pack is considered complete enough for implementation because it now includes:
- product direction
- execution order
- backend plan
- deployment strategy
- API draft
- schema draft

Proceed using staged execution, not a monolithic rewrite.
