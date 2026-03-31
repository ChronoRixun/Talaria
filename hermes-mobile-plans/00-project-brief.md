# Hermes Mobile Project Brief

## One-line Goal
Build Hermes Mobile, a native SwiftUI iPhone app that serves as the trusted device client for a persistent Hermes agent system.

## Product Vision
Hermes Mobile should become a high-quality personal AI companion app that combines:
- text chat
- realtime voice Talk Mode
- user-approved access to device capabilities
- asynchronous Hermes requests and notifications
- background-safe sync behavior
- durable state across app launches

The app is not the always-on agent runtime. Hermes itself should run remotely or on a continuously available host. The iOS app should provide:
- native UI and interaction surfaces
- secure access to device capabilities when the user authorizes them
- foreground voice session UX
- local persistence
- push-opened inbox/actions
- a continuation point for deeper Hermes workflows

## Why This Architecture
This design aligns with:
- iOS background execution constraints
- privacy and consent expectations for Location, Health, Photos, Camera, and Notifications
- the way Hermes-style agent harnesses work best: persistent tools, durable state, and long-running asynchronous execution outside the app lifecycle

## Phase Breakdown

### Phase 1: Frontend MVP shell
Build a compileable native app with:
- Chat
- Talk Mode
- Permissions
- Inbox
- Settings
- local state
- mock services
- backend-ready interfaces

### Phase 2: First live backend integration
Add:
- device registration
- auth bootstrap
- secure token storage
- Hermes chat transport
- APNs token registration
- inbox fetch and action callbacks

### Phase 3: Capability wiring
Add:
- CoreLocation-backed authorization + snapshot flows
- HealthKit authorization + summaries
- camera/photos user-driven flows
- PencilKit or canvas flows

### Phase 4: Realtime voice + background polish
Add:
- OpenAI Realtime Talk Mode
- backend-issued ephemeral session/token flow
- silent push where appropriate
- background refresh / sync coordination
- App Intents, widgets, or snippets as appropriate

## Product Surfaces
Core app surfaces:
- Chat
- Talk Mode
- Permissions & Privacy
- Inbox / Requests
- Settings
- Capture / Canvas entry points

Future system surfaces:
- push notifications
- Live Activities where appropriate
- App Intents / Shortcuts / Action button integration
- optional interactive snippets or quick actions on supported iOS surfaces

## Core Principles
- native first
- privacy first
- user-authorized access only
- clean service seams
- protocol-driven integrations
- no fake backend assumptions in the UI layer
- Hermes-compatible continuation points

## What “complete app” means in planning terms
This planning pack should support the complete product buildout, not just the first SwiftUI screens. That means the docs must cover:
- frontend architecture
- backend relay architecture
- provider selection tradeoffs
- iOS 26-era background and system integration constraints
- Hermes agent compatibility
- staged continuation for Claude Code or Codex

## Non-goals
The app should not attempt to:
- host the full Hermes runtime permanently on-device
- rely on unlimited background execution
- treat camera as background-accessible
- bypass Apple permission and review expectations
- use VoIP/CallKit or other sensitive background modes for generic assistant persistence

## Preferred end-state architecture
- iOS app: SwiftUI client and device capability endpoint
- Hermes runtime: remote/server/local always-on runtime outside iOS lifecycle
- backend relay: auth, APNs, ephemeral credentials, inbox events, sync API, media upload plumbing
- data store: session state, inbox items, device registry, permission policy snapshots, audit logs

## Strong default recommendation
For this product, the best default architecture is:
- app connects directly to OpenAI Realtime during foreground Talk Mode using backend-issued ephemeral credentials
- Hermes backend remains the durable orchestrator for messages, tasks, tools, and async workflows
- the relay mediates auth, push, device registration, and capability-related requests
