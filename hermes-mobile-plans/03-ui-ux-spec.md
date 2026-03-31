# Hermes Mobile UI/UX Specification

## Design Tone
- premium
- calm
- privacy-forward
- Apple-native
- lightweight, not cluttered

## Visual Themes
- support light and dark mode
- subtle card surfaces
- comfortable spacing
- rounded controls and state pills
- clear hierarchy
- tasteful animation only where it improves feedback

## Root Navigation
Preferred tabs:
- Chat
- Talk
- Inbox
- Settings

Permissions should be surfaced inside Settings and may also be reachable from context-specific cards.

---

## Chat Screen

### Purpose
Primary ongoing conversation screen for text interaction with Hermes.

### Required UI
- navigation title or branded header
- connection/mock mode status strip
- message list
- differentiated user and Hermes message bubbles
- timestamps
- bottom composer bar
- attachment placeholder button
- send button
- entry point to Talk Mode

### Recommended states
- loading conversation
- empty state
- populated conversation

### UX notes
- keep bubble layout clean and roomy
- Hermes messages should feel assistant-like, not chat-room-like
- show mock/local mode in a restrained way
- sending a message should feel responsive immediately

---

## Talk Mode Screen

### Purpose
Dedicated voice interaction surface.

### Required UI
- large central orb, pulse, or waveform placeholder
- state label
- transcript preview area
- mute control
- end session control
- optional session timer
- mock mode label

### Voice states
- idle
- listening
- thinking
- speaking
- disconnected

### UX notes
- this screen should feel like a focused immersive mode
- use animation to communicate state, not decoration for decoration’s sake
- controls should stay obvious and thumb-friendly

---

## Permissions & Privacy Screen

### Purpose
Central location for capability transparency and permission management.

### Required rows/cards
- Location
- Health
- Notifications
- Camera
- Photos

### Each item should include
- icon
- title
- concise explanation
- current permission state
- action button

### Copy tone
Use language like:
- “You choose what Hermes can access.”
- “Access can be changed later in Settings.”
- “Hermes only uses the data you authorize.”

Avoid language that implies unrestricted access.

---

## Inbox Screen

### Purpose
Surface pending requests and async follow-up actions from Hermes.

### Required UI
- list of inbox items
- item type or priority badge
- title and supporting description
- timestamp or recency hint
- action buttons such as Approve, Dismiss, Open

### Example items
- request location snapshot
- review photo request
- confirm notification preference
- reminder or follow-up task

### UX notes
- should feel like the future landing zone for push-opened tasks
- item actions should be direct and obvious

---

## Settings Screen

### Purpose
Home for device identity, app configuration, privacy, connection visibility, and debug info.

### Suggested sections
- account/device
- Hermes connection
- notifications
- privacy & permissions
- local data / debug
- about

### Show placeholders for future values
- device registered
- last sync time
- push token status
- backend endpoint

### UX notes
- do not expose raw implementation noise
- present future technical details in a calm, product-oriented way

---

## Capture / Canvas Placeholder

### Purpose
Reserve UI space for future media and drawing workflows.

### MVP requirement
A simple card or destination is enough if it:
- clearly signals future capability
- fits into the app’s navigation naturally
- does not feel broken or abandoned

---

## Empty State Guidance
Where screens can be empty, include copy that feels intentional.

Examples:
- Chat: “Your conversation with Hermes will appear here.”
- Inbox: “No pending requests right now.”
- Talk: “Start a voice session when you’re ready.”

## Motion Guidance
Use subtle animation for:
- Talk Mode orb/pulse
- message appearance
- status changes
- selection state changes

Avoid gratuitous transitions.

## Accessibility Guidance
- support dynamic type reasonably
- keep tap targets large enough
- ensure color is not the only status indicator
- provide icon + text pairings for permission and connection states
