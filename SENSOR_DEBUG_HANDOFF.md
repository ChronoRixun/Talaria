# Sensor Pipeline Debug — Session Handoff

**Date:** 2026-06-23  
**Branch:** `feat/phase-b-wiring` (commit `84e4127`, pushed)  
**Prior session transcript:** `/mnt/transcripts/2026-06-24-03-59-45-talaria-t1-t2-models-shim-sensors.txt`

---

## What happened this session

### Completed (on `main` via merge `98a9a89`)
- **T1**: Settings→Models wired to live shim (ModelsShimClient, ModelsSettingsScreen, dual-write picker)
- **T2**: Regex fix (model IDs with `/`) + copy fix ("SWITCH APPLIES THIS SESSION")
- **Shim cache-bust**: `_set_default` now invalidates GET cache immediately
- **Merge to main**: `feat/phase-b-wiring` → `main` (no-ff), pushed

### Completed (on branch, post-merge)
- **On-device deployment**: Built for physical iPhone (whoGoesThere), installed via `devicectl`
- **OPEN_ITEMS.md**: 15 items tracked (items 1–15)
- **DEVELOPMENT_TEAM**: Set `DNL25ZFSD2` in `project.yml` + `pbxproj` for CLI device builds
- **Sensor diagnostic logging**: `os_log` instrumentation added (see below)

### In progress — sensor pipeline is stale
All sensor data on the phone is from June 16 (from Dylan's original Hermes iOS install).
Owen granted permissions on the fresh Talaria install but no new data is flowing.

---

## The problem

The sensor upload pipeline has **four silent gates** in `drainOutboxIfPossible()`. If any
fails, the method returns without logging, surfacing errors, or retrying. Before this
session, there was zero observability into which gate was blocking.

### Architecture reminder
```
Chat path:  Phone → mini (100.79.222.100:8642) → Hermes gateway on mini
Sensor path: Phone → relay at OJAMD (100.110.102.59:8000) → connector → OJAMD's Hermes
```
These are TWO separate Hermes instances. Chat works fine. Sensors upload through the relay.

### Drain gates (in order)
1. `guard !isDraining` — re-entrancy guard
2. `guard isActive` — requires `start()` to have been called
3. `guard isPairedProvider()` — `activePairingStore?.isPaired == true`
4. `guard let accessToken = await accessTokenProvider()` — `sessionStore.currentAccessToken()`

### AppContainer gates (before sensor service is even touched)
In `initialize()`:
- `guard pairingStore.isPaired` — must have an active pairing
- `guard await sessionStore.currentAccessToken() != nil` — clears pairing if nil
- `guard sessionStore.state.connectionStatus == .connected` — aborts init if not connected

In `handleAppDidBecomeActive()` (called on every foreground):
- `guard pairingStore.isPaired` — again
- `guard await sessionStore.currentAccessToken() != nil` — again

---

## What we know so far

### Console.app output (first capture, pre-privacy-fix)
```
22:54:32.312  start() — activating sensor pipeline. Outbox: loc=true, health=6
22:54:32.319  start() — monitoring started (loc/health/motion). Health auth=<private>, loc auth=<private>
```

### Interpretation
1. **`start()` IS firing** — the service activates and the outbox has stale data (1 loc + 6 health)
2. **Monitoring started** — location/health/motion callbacks are registered
3. **Auth values were `<private>`** — iOS redacts `os_log` dynamic values by default
4. **NO drain logs appeared** — `drainOutboxIfPossible()` was never called, or it was
   called but its output wasn't captured

### What's missing
- No `handleAppDidBecomeActive` log from either AppContainer or SensorUploadService
- No drain gate logs (`BLOCKED — not paired`, `BLOCKED — no access token`, etc.)
- No callback logs (📍 location, 💓 health, 🏃 activity)
- No upload result logs

### Most likely blockers (ranked)
1. **AppContainer.handleAppDidBecomeActive() blocked by pairing or token** — this gates
   before the sensor service's own `handleAppDidBecomeActive()` is called
2. **isPairedProvider() returns false** — the pairing store doesn't think we're paired
   with OJAMD's relay
3. **accessTokenProvider() returns nil** — no relay session token

---

## Diagnostic logging added (commit `7639ec1`)

### SensorUploadService.swift
All methods now log via `Logger(subsystem: "org.aethyrion.talaria", category: "SensorUpload")`:
- `start()`: activation + outbox state + auth status (`.public` privacy)
- Callbacks: 📍 location, 💓 health, 🏃 activity — each logs when fired
- `handleAppDidBecomeActive()`: logs entry + guard failure
- `captureHealthSnapshot()`: logs nil snapshot (with auth), empty snapshot, or sample count
- `drainOutboxIfPossible()`: logs each gate hit (isDraining, isActive, isPaired, accessToken)
  + drain start/finish with outbox counts
- `performAuthorizedUpload()`: logs 401 + refresh attempt, generic errors
- `executeUpload()`: logs deliveryState + wasDelivered per upload

### AppContainer.swift  
`Logger(subsystem: "org.aethyrion.talaria", category: "AppContainer")`:
- `initialize()`: logs connectionStatus gate failure + sensor service start
- `handleAppDidBecomeActive()`: logs isPaired gate, accessToken gate, or "proceeding"

### Privacy fix
All diagnostic interpolations use `privacy: .public` so values are visible in Console.app
without a device profile. The earlier capture showed `<private>` — that's now fixed.

---

## How to continue

### Step 1: Get the diagnostic logs
The latest build with full logging is already deployed to Owen's phone.

1. Open **Console.app** on the mini
2. Select **whoGoesThere** in the sidebar
3. Search filter: `org.aethyrion.talaria` (catches both AppContainer + SensorUpload)
4. **Background the app** (swipe up) then **re-open it**
5. Read the logs — one of these will appear:
   - `handleAppDidBecomeActive: BLOCKED — not paired` → **pairing is the issue**
   - `handleAppDidBecomeActive: BLOCKED — no access token` → **session token issue**
   - `drain: BLOCKED — isPairedProvider() returned false` → pairing gate in sensor service
   - `drain: BLOCKED — accessTokenProvider() returned nil/empty` → token gate in sensor
   - `drain: starting` → drain is attempting, look for upload results
   - `upload device/sensor/location: error —` → relay HTTP error (will include description)

### Step 2: Fix based on diagnosis
- **Pairing issue**: The phone may need to re-pair with OJAMD's relay. Check if
  `PairingStore.isPaired` is reading from a stale Dylan install. May need to clear
  local pairing and re-pair with the 8-digit code.
- **Token issue**: `sessionStore.currentAccessToken()` returns the relay session token,
  not the Hermes API key. If the session expired or was never created on the relay,
  the token will be nil.
- **Relay HTTP error**: OJAMD's relay may be rejecting the upload (wrong path, auth
  mismatch, etc.). Check the error description in the logs.

### Step 3: After sensors work
- Remove or gate the verbose logging behind `#if DEBUG`
- Merge branch to main
- Proceed with Open Items (see `OPEN_ITEMS.md` for the full backlog)

---

## Build & deploy commands (for reference)

```bash
# Build for physical device (from mini terminal)
cd /Users/owenjones/Documents/Claude/Talaria
env DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project Talaria.xcodeproj -scheme Talaria \
  -destination 'id=91CBCB90-B313-5B09-A405-E0FE284C9D75' \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=DNL25ZFSD2 build

# Install
PHONE=91CBCB90-B313-5B09-A405-E0FE284C9D75
APP="$HOME/Library/Developer/Xcode/DerivedData/Talaria-bkmofmhhchhruzcdudrizbbblrae/Build/Products/Debug-iphoneos/Talaria for Hermes Desktop.app"
xcrun devicectl device install app --device "$PHONE" "$APP"

# Launch
xcrun devicectl device process launch --device "$PHONE" org.aethyrion.talaria
```

**Note:** `log stream --device` does NOT work for physical devices. Use Console.app
(Mac sidebar → phone) or Xcode's debug console (⌘R). The zsh `log` builtin shadows
`/usr/bin/log` — use the full path if needed.

---

## Key files modified this session

| File | What changed |
|------|-------------|
| `Talaria/Services/Live/SensorUploadService.swift` | os_log instrumentation (all gates + callbacks + uploads) |
| `Talaria/Stores/AppContainer.swift` | os_log for initialize() + handleAppDidBecomeActive() gates |
| `OPEN_ITEMS.md` | Added item #15 (in-app sensor diagnostics panel) |
| `project.yml` | DEVELOPMENT_TEAM set to DNL25ZFSD2 |
| `Talaria.xcodeproj/project.pbxproj` | Same DEVELOPMENT_TEAM change |

---

## Open Items summary (see OPEN_ITEMS.md for details)

| # | Status | Item |
|---|--------|------|
| 1 | 🔧 | T4 Host reconciliation (localhost → tailnet IP before TestFlight) |
| 2 | ⛔ | T3 Settings screens (blocked on Settings.dc.html design deliverable) |
| 3 | 📝 | xcodegen needed when adding/removing source files |
| 4 | 💤 | Expensive-model confirm guard (wired, dormant) |
| 5 | 📝 | Host-status display quirk (OFFLINE·STANDBY vs CONNECTED) |
| 6 | 📝 | config.yaml provider normalization (kimi-for-coding → kimi-coding) |
| 7 | 📝 | DEBUG shim-token launch-env seam |
| 8 | 📝 | TestFlight (gated on T4 + tailscale serve) |
| 9 | 📝 | Model-selection waiting animation (needs Claude Design) |
| 10 | 🐛 | Top-center chip shows placeholder, not active model |
| 11 | 🐛 | Settings back-nav exits Settings instead of popping |
| 12 | 🐛 | Sensor data stale (THIS INVESTIGATION) |
| 13 | 🐛 | Model identity unreliable (app displays config, not reality) |
| 14 | 📝 | Shim token onboarding (needs frictionless flow) |
| 15 | 📝 | In-app sensor diagnostics panel |
