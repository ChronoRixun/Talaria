# Palette-Core De-Duplication — Handoff (Issue #49)

**For:** a Mac Claude Desktop session (Xcode + `DesignThemeTests` must run locally).
**Status:** not started. Written 2026-07-05 after PR #38 (theme catalog foundation) merged.

## Mission

Make `ThemePalette` resolve from the `ThemeCatalog` data model (#38) instead of
hand-written switch arms, so a new theme becomes one catalog entry instead of a
5-file edit. Full rationale: `design/THEME_FRAMEWORK_PLAN.md` §6. This doc is the
concrete execution plan against the actual current code.

## Required environment

- **Mac Mini only** (`Owens-Mac-mini`) — `DesignThemeTests` is the guard for this
  entire piece of work and can only be *run* via Xcode, not the CLI.
- Repo: `/Users/owenjones/Documents/Claude/Talaria`, branch off `main`, PR back to
  `ChronoRixun/Talaria`.
- Build: `env DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild build -project Talaria.xcodeproj -scheme Talaria -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
- `xcodegen generate` is mandatory after adding/removing Swift files (this work
  will add/rename files). After every run, verify `aps-environment: development`
  is still present in `Talaria/Talaria.entitlements` — prior runs have stripped it
  (#44/#48).
- **`DesignThemeTests` and `ThemeCatalogTests` cannot be run via `xcodebuild test`**
  — the CLI can't resolve the `TalariaTests` test host (#51/#52). Run them in
  Xcode (Cmd+U or the Test navigator) after every themed ported below.

## The guard

`TalariaTests/DesignThemeTests` verifies Deep Field × cyan is byte-identical to
the pre-theming constants. It must stay green after every single commit in this
sequence — zero tolerance, not even a 1-unit hex channel drift. If you can't tell
whether a value changed, diff the resolved hex against the current switch arm
before committing, don't rely on the test alone to catch it.

## Current state (as of 2026-07-05, post #38 + #36)

- **`Shared/ThemePaletteCore.swift`** (418 lines) — the real target. `ThemeID` /
  `AccentSlot` enums (decoupled from the app's `AppearanceTheme` / `AppearanceAccent`,
  same raw values, do not rename). `ThemePalette` struct has ~30 stored properties
  across 6 groups: environment, foreground ramp, surfaces/borders, accent family,
  semantic colors, behavior knobs. Four private inits (`deepField`, `solarForge`,
  `terminal`, `paperTape`), each a switch on `AccentSlot` producing hex literals +
  gradient stops + drawer colors + grid params. `ThemeID.lockedAccentSlot`
  special-cases Terminal to always resolve `.cyan` regardless of the persisted
  accent (#12) — this pin behavior must be preserved by whatever replaces the
  switch, as data or otherwise.
- **`Talaria/Core/Design.swift`** — thin delegate only. `ThemeRuntime.palette`
  calls `ThemePalette(theme: theme.themeID, accent: accent.slot)`;
  `AppearanceTheme.themeID` is a 1:1 raw-value mapping extension. Low risk —
  updates automatically once the constructor's signature is stable.
- **`Talaria/Core/HUD/ReactorOrb.swift`** — **not a color-data switch.** Switches
  on `ThemeRuntime.shared.theme` to pick an entirely different SwiftUI view
  builder per theme (`deepFieldLayers`, `solarForgeLayers`, `terminalLayers`,
  `paperTapeLayers` — distinct particle/HUD compositions, not just recolored
  views). A pure data catalog doesn't naturally absorb this. **Open design
  decision, not an oversight:** either the catalog carries a builder
  closure/identifier the orb dispatches on, or `ReactorOrb` keeps its own small
  theme switch permanently. Pick one and document why in the PR.
- **`TalariaWidgets/WidgetTheme.swift`** (99 lines) — small switch mapping widget
  cases to `ThemePalette(theme: .deepField/.solarForge/etc, accent: .cyan)`, plus
  one case reading `data.appearanceTheme` (a raw string) via
  `ThemeID.init(rawValue:)`. Easy to make catalog-driven — the string round-trip
  already exists.
- **`Talaria/Models/UserSettings.swift`** — `enum AppearanceTheme` is the persisted
  identity; also carries `displayLabel` and `isLight` as small per-case switches.
  **Note:** `ThemeDefinition` (from #38, `Models/ThemeCatalog.swift`) already
  carries `displayName`. There is latent duplication between
  `AppearanceTheme.displayLabel` and `ThemeDefinition.displayName` today —
  reconcile this to a single source of truth as part of this work, don't leave
  two names that can drift apart.

## Target shape (per THEME_FRAMEWORK_PLAN.md §6)

- Move each theme's resolved palette (colors + gradient stops + drawer colors +
  grid params) out of the private inits into a data payload owned by (or
  referenced from) `ThemeDefinition`.
- `ThemePalette(theme:accent:)` resolves via catalog lookup, not a switch.
- Preserve the `lockedAccentSlot` pin (Terminal → cyan) as data, not a
  special-cased switch.
- Reconcile `AppearanceTheme.displayLabel` / `isLight` vs.
  `ThemeDefinition.displayName` duplication.
- Decide and document `ReactorOrb`'s fate (see above).
- Once all 4 themes are ported and the above is settled: `AppearanceTheme`
  collapses to a thin id (or is removed in favor of `ThemeDefinition.id`).

## Suggested sequencing

1. **Dry run on a non-guarded theme first** — Solar Forge or Paper Tape
   (structurally simplest, no `lockedAccentSlot` special case) — to prove the
   extraction pattern without touching the byte-identical path. `DesignThemeTests`
   should stay trivially green here since Deep Field is untouched; this step
   validates your migration code, not the guard.
2. **Port Terminal next** — same pattern, plus wire up `lockedAccentSlot` as data
   instead of the `ThemeID` extension special case. Run `DesignThemeTests` again.
3. **Port Deep Field last, under maximum scrutiny** — this is the one the guard
   actually checks. Diff every resolved hex value against the current switch arm
   output before committing. `DesignThemeTests` must pass with zero tolerance.
4. **Only after all 4 are ported and green:** decide + execute the
   `AppearanceTheme` collapse.
5. Commit after each theme individually (small, reviewable diffs) rather than one
   giant commit — easier to bisect if `DesignThemeTests` breaks.

## Verification checklist (before opening the PR)

- [ ] `xcodegen generate` run (new/removed files) — commit the regenerated `project.pbxproj`
- [ ] `Talaria/Talaria.entitlements` still has `aps-environment: development` (#44/#48)
- [ ] `xcodebuild build` (command above) — BUILD SUCCEEDED
- [ ] `DesignThemeTests` run **in Xcode** (not CLI) — green
- [ ] `ThemeCatalogTests` run in Xcode — green
- [ ] Simulator/device: cycle all 4 themes × 3 accents, confirm no visual
      regression; confirm Terminal still pins to cyan regardless of persisted accent

## References

- Issue #49 (this work) · #24 (umbrella, closed) · #50 (seasonal/holiday content —
  depends on this landing if new palettes are meant to be genuinely new visual
  identities rather than reused `AppearanceTheme` cases)
- `design/THEME_FRAMEWORK_PLAN.md` §6 — original sequencing rationale
- PR #38 — the metadata-layer foundation this builds on
