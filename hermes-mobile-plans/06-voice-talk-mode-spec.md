# Hermes Mobile Talk Mode Specification

## Purpose
Talk Mode is the dedicated voice-first interaction screen for Hermes Mobile. In the frontend MVP, it should feel intentional and premium even though the underlying realtime voice transport is not yet implemented.

## Product Role
Talk Mode should eventually become the foreground live session experience for realtime voice conversations with Hermes.

In phase 1, build only the local UI shell and state transitions.

## Required States
- idle
- listening
- thinking
- speaking
- disconnected

## Required UI Elements
- title/header
- central orb, pulse, or waveform-style visual
- current status label
- transcript preview area
- mute toggle
- end session button
- optional timer
- mock mode indicator

## Interaction Requirements
- user can enter the screen from main navigation or from Chat
- user can start a mock session
- user can toggle mute
- user can end the session
- the screen can simulate status transitions
- transcript preview should update based on current state or mock data

## Visual Behavior Guidance
### Idle
- calm, low-motion visual
- CTA to start or enter listening state

### Listening
- active pulse animation
- transcript preview may show partial user speech

### Thinking
- restrained animated processing feel
- transcript preview may show “Hermes is thinking…”

### Speaking
- more animated output state
- transcript preview or response text can show mock reply snippets

### Disconnected
- neutral warning state with reconnect language appropriate for a future live implementation

## Copy Guidance
Avoid pretending the app is already using live voice if it is not. A subtle badge like “Mock Voice Session” or “Realtime voice coming next” is acceptable.

## Future Integration Seams
Later this screen should be wired to:
- OpenAI realtime voice transport
- Hermes tool invocation/orchestration layer
- audio session handling
- streaming transcript updates
- interruption handling
- optional voice preference settings

## Phase 1 Acceptance Criteria
- screen is visually distinct from chat
- all voice states can be demonstrated locally
- user controls are obvious
- layout looks strong in light and dark mode
- no real streaming dependency is required
