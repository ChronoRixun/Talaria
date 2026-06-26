# T3 — Settings Screens Build

## What this is

Build the 6 remaining Settings screens for Talaria from the Claude Design spec at `design/Settings.dc.html`. The MODELS screens (03/04) are already built (`ModelsSettingsScreen.swift`). You're building:

1. **01 SYSTEM** — Index/hub. Navigation links to all other screens.
2. **02 UPLINK** — Host connection. Hermes API URL, API key, relay config.
3. **05 VOICE** — Talk engine settings.
4. **06 APPEARANCE & HUD** — Theme colors (cyan default, violet alt, etc.), grid intensity, glow effects.
5. **07 SESSIONS** — Session data management, clear-all, export.
6. **08 DIAGNOSTICS** — System health, sensor pipeline status, about/version info.

## Design spec

Open `design/Settings.dc.html` in a browser (needs `design/support.js` alongside it). It's a Claude Design canvas showing all 8 screens as a vertical stack. Each screen shows the exact layout, typography, spacing, and component structure. Match it closely — the Jarvis HUD aesthetic is precise.

There's also `design/Settings-ModelTransition.dc.html` — the model switch animation spec for #9 (wire it into the existing `ModelsSettingsScreen` after the screens are built).

## Architecture

- **Repo:** `/Users/owenjones/Documents/Claude/Talaria`
- **Existing Settings:** `Talaria/Features/Settings/SettingsScreen.swift` (808 lines — the current monolith that gets replaced by the new index screen)
- **Existing Models:** `Talaria/Features/Settings/ModelsSettingsScreen.swift` (already built, keep as-is)
- **Design system:** `Talaria/Core/Design.swift` — all colors, typography, spacing, corner radii are here. Use `Design.Colors.*`, `Design.Typography.*`, `Design.Spacing.*`, `Design.Brand.*`, `Design.CornerRadius.*`.
- **HUD components:** `hudPanel()`, `HUDScreenBackground()`, `GlowButton`, `MonoLabel`, `StatusPip`, `GlassCircleButton`, `ReactorOrb` — all exist in `Talaria/Core/`.
- **Section wrapper:** `SettingsSectionView` exists for grouping rows.
- **Router:** `SheetDestination.settings` in `Router.swift` opens Settings. The new SYSTEM index uses `NavigationLink` to push sub-screens within the `NavigationStack`.
- **Build:** `env DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild ...` (Xcode beta 27.0 required for device targets)
- **Source files:** `project.yml` uses folder-based sources. Run `xcodegen generate` after adding new `.swift` files.

## Key data sources for each screen

### 01 SYSTEM (index)
- Navigation links to: Uplink, Models, Voice, Appearance, Sessions, Diagnostics
- Show counts/status inline (e.g. "48 SESSIONS", model name, connection status)
- `container.chatStore.activeModelName` for the model label
- `effectiveConnectionState` for uplink status (already on SettingsScreen — use same pattern)

### 02 UPLINK
- `settingsStore.settings.hermesAPIBaseURL` — Hermes API base URL
- `container` has `chatAPIKeyBox` — API key (Keychain)
- `settingsStore.settings.relayConfiguration` — relay mode, custom URL
- `settingsStore.settings.modelsShimBaseURL` — shim URL
- Connection test: `hostStore.refresh()` or `chatStore.directConnectionStatus`
- The shim token field should note it's optional now (#14 — falls back to API key)

### 05 VOICE
- `settingsStore.settings` for voice/talk preferences
- Existing talk infrastructure in `Talaria/Features/Talk/`

### 06 APPEARANCE & HUD
- Theme color switching (cyan `#54e6f0` default, violet alt, etc.)
- Grid intensity, glow effects
- Add new `UserSettings` fields to `Talaria/Models/UserSettings.swift`

### 07 SESSIONS
- `chatStore.loadSessions()` returns `[HermesSessionInfo]` (50 sessions confirmed working)
- `chatStore.clearConversation()` for clearing current

### 08 DIAGNOSTICS
- Sensor pipeline state from `AppContainer`
- Connection log / uplink history
- App version: `Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")`
- Overlaps with open item #15 (sensor diagnostics panel) and #23 (revoke permissions)

## Current SettingsScreen.swift → SYSTEM index

Replace the current monolith body with the new 01 SYSTEM index. Move existing sections:
- Connection + Hermes API + Relay → **02 UPLINK**
- Models → already in `ModelsSettingsScreen.swift`
- Preferences + Location → **05 VOICE** or **06 APPEARANCE**
- Privacy → **06 APPEARANCE** or **07 SESSIONS**
- About → **08 DIAGNOSTICS**
- Internal Environment → **08 DIAGNOSTICS** (dev section)

## Style rules

- All screens: `HUDScreenBackground(gridIntensity: 0.35)` + `.ignoresSafeArea()`
- Custom back button: `GlassCircleButton(icon: "chevron.left", ...) { dismiss() }`
- Screen title: `Design.Typography.screenTitle2` + `Design.Tracking.display`
- Section headers: `MonoLabel` with `Design.Tracking.monoWide`
- Row labels: `Design.Typography.body(15, weight: .medium)`
- Use `hudPanel()` for containers, `Design.Colors.cyanHairline` for borders
- `effectiveConnectionState` pattern (prefer direct over relay) already exists — reuse it

## Files to create

```
Talaria/Features/Settings/SystemSettingsScreen.swift      (01 - index)
Talaria/Features/Settings/UplinkSettingsScreen.swift      (02 - connection)
Talaria/Features/Settings/VoiceSettingsScreen.swift       (05 - talk engine)
Talaria/Features/Settings/AppearanceSettingsScreen.swift  (06 - HUD theme)
Talaria/Features/Settings/SessionsSettingsScreen.swift    (07 - data)
Talaria/Features/Settings/DiagnosticsScreen.swift         (08 - about/health)
```

Run `xcodegen generate` after creating files and commit the regenerated `project.pbxproj`.
