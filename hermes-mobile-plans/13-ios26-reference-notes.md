# iOS 26 Reference Notes

These notes summarize Apple documentation and platform guidance relevant to Hermes Mobile as of March 2026.

This file is not a substitute for reading Apple docs directly during implementation, but it captures the key constraints and opportunities that should shape the architecture.

---

## 1. Background tasks
Relevant Apple docs:
- `Background Tasks`
- `Performing long-running tasks on iOS and iPadOS`
- `Configuring background execution modes`

Key points:
- `BGAppRefreshTask` is for short refresh work
- `BGProcessingTask` is for longer deferred background processing
- `BGContinuedProcessingTask` is for user-initiated work that starts in the foreground and may continue if the user backgrounds the app
- continuous background tasks are not a general-purpose forever-running assistant mechanism
- the system can still terminate background work under resource pressure
- task progress should be reported accurately

Implication for Hermes Mobile:
- do not design around a persistent on-device Hermes runtime
- use backend durability and push/inbox instead
- reserve background task APIs for legitimate refresh, processing, upload, or user-initiated continuation flows

---

## 2. Background push notifications
Relevant Apple doc:
- `Pushing background updates to your App`

Key points:
- background notifications wake the app to refresh content
- they are low priority and not guaranteed
- Apple warns against excessive frequency and suggests not trying to send more than roughly two or three per hour
- the system may coalesce, delay, or discard them
- if the app is force-quit, held background notifications may be discarded

Implication for Hermes Mobile:
- visible user-facing push is more reliable for user attention
- background push is only a sync hint, not a guaranteed execution channel
- backend remains the durable truth source

---

## 3. Core Location background behavior
Relevant Apple docs:
- `Handling location updates in the background`
- `Core Location updates`
- `startMonitoringSignificantLocationChanges()`
- `allowsBackgroundLocationUpdates`

Key points:
- iOS suspends most background apps
- location updates may be queued and delivered later unless you have the right background setup
- background location use requires explicit capabilities and careful justification
- newer Core Location APIs include `CLServiceSession` and `CLBackgroundActivitySession`
- significant-change monitoring can relaunch the app after termination when a qualifying event occurs

Implication for Hermes Mobile:
- prefer low-power or event-based patterns over continuous tracking
- start with location snapshot and significant-change/geofence-style products, not a raw continuous tracker
- explain background behavior clearly if you ever request Always authorization

---

## 4. HealthKit background delivery
Relevant Apple docs:
- `Executing Observer Queries`
- `enableBackgroundDelivery(for:frequency:withCompletion:)`
- `Configuring HealthKit access`

Key points:
- observer queries notify the app that a change happened, not what changed
- you must follow with another query, such as anchored queries, to fetch the data
- background delivery requires the proper entitlement
- Apple advises setting up observer queries at app launch if you depend on background delivery
- simulator is insufficient for background query validation; test on device

Implication for Hermes Mobile:
- expose summarized health data, not raw unrestricted store access
- implement health background behavior only after the relay, consent, and policy model are in place

---

## 5. App Intents and snippets
Relevant Apple docs:
- `App Intents`
- `Displaying static and interactive snippets`
- `SnippetIntent`
- `Accelerating app interactions with App Intents`

Key points:
- App Intents are now a core way to expose app actions across Siri, Spotlight, widgets, controls, and related system experiences
- snippets can show static or interactive SwiftUI views tied to intents
- snippets are useful for contextual follow-up actions without forcing a full app launch in every case
- snippets are not displayed from every surface, for example there are constraints in some Control Center contexts

Implication for Hermes Mobile:
- App Intents are a strong future extension point for “Talk to Hermes”, “Show Inbox”, “Request Check-in”, or “Send to Hermes” flows
- interactive snippets may become a nice later-phase surface for approvals or results, but they are not required for the MVP

---

## 6. Realtime voice implications
Apple does not provide a generic “always-on third-party assistant runtime” model for apps like this.

Implication for Hermes Mobile:
- foreground Talk Mode is the right primary voice model
- when the app is not active, fall back to notifications, inbox, and quick re-entry surfaces
- do not architect around indefinite hidden microphone or arbitrary background conversation continuity

---

## Source references used while updating this planning pack
Apple docs reviewed included pages for:
- Background Tasks / BGContinuedProcessingTask
- Pushing background updates to your App
- Handling location updates in the background
- Executing Observer Queries
- App Intents / SnippetIntent / displaying static and interactive snippets
