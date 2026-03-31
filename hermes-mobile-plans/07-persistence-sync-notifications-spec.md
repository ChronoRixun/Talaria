# Hermes Mobile Persistence, Sync, and Notifications Spec

## Goal
Define what should persist locally now, what should sync later, and how background and push behavior should be designed to match iOS realities as of March 2026.

## Phase 1 Persistence Scope
Persist only what improves the experience immediately.

Recommended:
- user settings
- selected environment
- last known connection/sync badge state
- optional most recent conversation snapshot
- optional inbox read/dismiss state

Recommended MVP implementation:
- a small UserDefaults-backed settings store
- optionally a lightweight local cache wrapper for seeded conversation state

Avoid a heavyweight offline engine until the live API contract is stable.

---

## Notifications Model
Notifications should ultimately serve two different product roles:

### 1. Attention notifications
Examples:
- Hermes sent a message
- Hermes needs approval for an action
- reminder or follow-up item

### 2. Background refresh hints
Examples:
- refresh inbox
- fetch new conversation state
- reconcile sync state

These should map respectively to:
- visible APNs notifications
- background notifications where appropriate

---

## Apple platform constraints to design around
From Apple documentation and platform guidance:
- background notifications are low-priority and not guaranteed
- Apple specifically notes not to rely on more than roughly two or three background notifications per hour
- the system may coalesce or discard older background notifications
- if the user force quits the app, queued background notifications may be discarded
- background execution remains system-managed and opportunistic

Implication:
The relay/backend must remain the durable source of truth. The app should sync opportunistically and present the freshest available state when opened or nudged by push.

---

## Phase 2+ Notification Plan

### Device registration
The app should register its APNs token with the relay.

### Relay behavior
The relay should:
- map device token to user/device record
- decide whether to send visible or background push
- avoid high-frequency background push spam
- dedupe noisy events

### App behavior
When push arrives, the app should:
- update inbox if possible
- refresh session state if appropriate
- route user to the relevant screen when opened from a visible notification

---

## Background execution plan
Use the following mechanisms appropriately:

### `BGAppRefreshTask`
Use for:
- lightweight inbox/session refresh
- refreshing local summaries
- low-cost sync reconciliation

### `BGProcessingTask`
Use for:
- heavier deferred sync work if ever needed
- larger local processing jobs not requiring immediate user response

### `BGContinuedProcessingTask`
Use only for:
- user-initiated foreground-started tasks that may continue if the user backgrounds the app
- for example, a future large export, upload, or local processing task

Do not misuse it as a keep-Hermes-alive mechanism.

### Background URLSession
Use for:
- media uploads
- larger downloads
- work that should continue across app state changes

### HealthKit background delivery
Use only after live capability wiring and only with the correct entitlement and device testing.

### Core Location background services
Use only when product value clearly justifies it and with explicit transparency to the user.

---

## Sync model recommendation

### Source of truth
Backend relay + Hermes system

### Local cache role
- improve perceived speed
- preserve minimal offline continuity
- reduce empty-state flicker

### Recommended sync shapes
- `lastSyncAt`
- `syncState`
- `pendingOutboundEvents`
- `pendingInboxActions`
- `conversationCursor`
- `inboxCursor`

### Suggested sync triggers
- app foreground
- pull to refresh
- visible push open
- background notification when delivered
- scheduled refresh opportunistically

---

## Future Inbox model
Inbox is the natural home for:
- pending approvals
- capability requests
- reminders
- device follow-ups
- post-voice-session summaries

This is important for Hermes compatibility because it gives the agent a durable async communication surface when realtime voice is not active.

---

## Acceptance criteria
Phase 1:
- at least one preference persists across relaunch
- notification status and sync status are visible in Settings
- code leaves clear APNs and sync seams

Phase 2+:
- visible and background push behaviors are separated conceptually
- relay owns delivery policy
- app remains functional even if background refresh is delayed or skipped by the system
