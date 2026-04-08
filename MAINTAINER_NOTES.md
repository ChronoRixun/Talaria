# Hermes iOS — Maintainer Notes

This file is for maintainers who want a short internal snapshot of the current implementation. It is **not** the recommended onboarding guide for public users.

Start here instead:

- [README.md](README.md)
- [connector/README.md](connector/README.md)
- [relay/README.md](relay/README.md)
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md)

## Current architecture

```text
iOS App ──HTTP/SSE──▶ Relay ──WebSocket──▶ Connector ──▶ Hermes Agent
```

## Current focus

- self-hosted-first setup
- public-safe defaults
- native iPhone UX for chat, voice, widgets, and sensor-aware context

## What is broadly working

- streaming chat and attachment delivery
- voice mode with Realtime bootstrap and Hermes delegation
- dynamic slash-command catalog from Hermes surfaces
- sensor pipeline (location, health, motion) through connector SQLite + MCP tools
- widgets, Live Activities, inline image rendering, and model/context UI
- APNs registration and relay-side delivery when configured

## What still requires physical-device validation

- APNs end-to-end on real Apple credentials
- background location behavior
- CarPlay entitlement path
- background audio continuity under real interruptions

## Test posture

- connector suite: passing
- relay suite: passing
- iOS build: passing
- targeted iOS tests: useful, but simulator launch flakes still happen intermittently

Treat this file as a maintainer note, not product documentation.
