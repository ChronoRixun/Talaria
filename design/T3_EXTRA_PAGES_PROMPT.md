# Claude Design — Talaria Settings: Additional Pages (T3 continuation)

## What I need
Design **4 new Settings sub-pages** for **Talaria**, extending the existing
`Settings.dc.html` mockup set in the **exact same visual language and single-file
HTML phone-frame format**. These give a home to settings the current SYSTEM index
(screen 01) doesn't yet cover, so nothing is orphaned when the index becomes the
Settings root.

**Deliverable:** one self-contained HTML file, same structure as `Settings.dc.html`
— a horizontal row of 392×850 phone frames, each labeled like `09 · RELAY — transport`.
Reuse the same CSS variables, fonts, and component patterns. No external assets.
These will be hand-built in SwiftUI from your mockups, so keep every control concrete
and standard (toggles, segmented pills, sliders, nav rows, text fields).

## Product context
Talaria is a personal AI-agent iOS app (SwiftUI) front-ending a self-hosted "Hermes"
backend. Aesthetic = HUD / "Jarvis": arc-reactor cyan on a dark teal field, mono
technical labels, cornered panels, subtle glow. Match screens 01–08 so these sit
seamlessly beside them.

## Visual system (match Settings.dc.html exactly)
- **Frame:** 392×850, inner radius 38, bg `radial-gradient(120% 70% at 50% -8%, #0c2730, #070d15 52%, #04070c)`, faint cyan grid overlay (lines `rgba(84,230,240,.045)`, 26px), notch, status-bar row (`9:41` Chakra + mono signal).
- **Accent vars:** `--accent:#54e6f0; --accent-bright:#cdf8fb; --accent-deep:#14636e;` amber `#ffc14d`; danger `#e0625f` / `#ff8a86`; muted `#5d7488`; body text `#e8eef5`.
- **Fonts:** Chakra Petch (titles + segments), Space Grotesk (row titles/body), JetBrains Mono (labels/values).
- **Header:** ‹ back circle (40px, border accent 26%, bg accent 6%); title Chakra 23px / 700 / letter-spacing 3px / `#eaf6f8`; subtitle mono 10px / ls 2.2px / `#5d7488`.
- **Section label:** `// NAME` — JetBrains Mono 10px / ls 2.4px / `#5d7488`.
- **Panel:** radius 14, bg `rgba(8,18,26,.5)`, border 1px `color-mix(accent 12%)`.
- **Row:** padding 15/16; 32px rounded icon tile (radius 9, border accent 18%, bg accent 5%) holding a small line-art glyph; title Space Grotesk 15px `#e8eef5`; trailing mono 10px accent value; `›` chevron accent 70%. Divider 1px accent 10%, margin `0 16px`.
- **Toggle:** 46×27 pill, knob 21. On = accent fill; off = grey (`#5d7488` knob on `rgba(120,150,175,.16)`).
- **Segmented:** container bg `rgba(6,8,12,.5)` / border accent 12% / radius 13; segment Chakra 11px / ls 2px; selected = accent bg, text `#04070c`, weight 600.
- **Slider:** 4px track `rgba(120,150,175,.18)`, accent fill, 17px accent-bright knob with glow.
- **Corner brackets** where it fits: 16px L-shapes, accent 55%.

## Pages to design

### 09 · RELAY — transport   (index group: `// CONNECTION`)
The relay-transport config, distinct from UPLINK (which is the direct Sessions-API
host + API key). Controls:
- `// MODE` segmented: **Use My Relay** / **Use Hosted Relay** (hosted may be
  unavailable in a build → render the hosted segment disabled with a one-line note).
- `// RELAY URL` mono text field, placeholder `http://ojamd:8000/v1`; validation hint
  line below (e.g. "Must be an absolute http(s) URL ending in /v1").
- Status panel: reachability pip + mono `LINKED · 20MS` / `STANDBY`.
- `// DEVICE` panel: pairing state (`PAIRED · whoGoesThere` / `NOT PAIRED`) with two
  actions — **Re-Pair** (accent) and **Forget Device** (danger).
- Toggle: **Auto-connect on launch**.
- Index row → icon: connected-nodes glyph; title "Relay"; trailing = active relay
  origin, e.g. `OJAMD · :8000`.

### 10 · NOTIFICATIONS — alerts   (index group: `// EXPERIENCE`)
- `// PUSH` panel: toggle **Push Notifications**, with a mono status line below:
  `TOKEN REGISTERED` / `NOT REGISTERED`.
- `// FEEDBACK` panel: toggle **Haptic Feedback**.
- Index row → icon: bell glyph; title "Notifications"; trailing = `ON` / `OFF`.

### 11 · PRIVACY — permissions   (index group: `// DATA & SYSTEM`)
Per-permission status + management; location detail; reset. **Real OS permissions only.**
- `// PERMISSIONS` panel, one row each — **Location, Health, Motion, Notifications,
  Microphone** — each with a status pip + mono state (`WHILE USING` / `ALWAYS` /
  `DENIED` / `NOT SET`) + a `MANAGE ›` affordance (opens iOS Settings).
- `// LOCATION` panel (meaningful only when authorized): accuracy readout
  (`FULL` / `REDUCED`); segmented **Foreground Only / Background** sync preference.
- Footer action: **Revoke / Reset Permissions** (danger) with a one-line caution.
- Index row → icon: shield/lock glyph; title "Privacy & Permissions"; trailing =
  `REVIEW` (or a granted count).

### 12 · DEVELOPER — debug   (DEBUG builds only; group: its own `// DEVELOPER`)
- `// ENVIRONMENT` segmented/list: **Production / Staging / Development**.
- Build info readout (version · build · commit) in mono.
- Index row (debug only) → icon: terminal glyph; title "Developer"; trailing =
  current env (`PRODUCTION`).

## Designer notes
- Keep every control mapped to something real; **never invent metrics** — where a
  value is unknown, show `—`.
- Same header pattern on every page (‹ back + Chakra title + mono subtitle).
- Match the spacing/scale of screens 01–08 so the set reads as one system.
- Output: a single HTML file, frames left-to-right, each labeled `NN · NAME — tag`,
  using the same wrapper markup as `Settings.dc.html`.
