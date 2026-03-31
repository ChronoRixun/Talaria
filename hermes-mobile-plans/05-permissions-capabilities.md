# Hermes Mobile Permissions and Device Capabilities Plan

## Objective
Design the frontend MVP so it presents device capabilities clearly and safely while leaving room for real permission handling later.

## Capability Set for MVP
- Location
- Health
- Notifications
- Camera
- Photos
- Canvas or drawing placeholder

## Product Principle
Hermes should be framed as using only the data the user explicitly authorizes. The permission UI must emphasize user control rather than capability breadth.

## Frontend MVP Requirements
The app should:
- display each capability as a separate permission item
- show current status
- explain why the capability might be used
- offer a clear next action
- handle denied and limited states gracefully

## Recommended UX Copy Direction
Use explanations similar to:
- Location: “Use your location for place-aware reminders and context when you approve it.”
- Health: “Share selected health summaries with Hermes only if you want wellness-aware assistance.”
- Notifications: “Allow Hermes to alert you about important updates and requests.”
- Camera: “Use the camera when you want Hermes to help with live visual input.”
- Photos: “Choose photos to share with Hermes for context or analysis.”

## Authorization Status Mapping
Your view layer should support these display states:
- Not requested
- Authorized
- Limited
- Denied
- Restricted
- Unsupported

Make sure the UI distinguishes:
- currently allowed
- partially allowed
- blocked by user or device policy

## MVP Implementation Strategy
For phase 1, real permission calls are optional except where trivial. It is acceptable to:
- fully mock most permission requests
- update local status when tapping request actions
- include TODO markers for real framework wiring

If implementing real permission logic, keep it isolated in service implementations only.

## Future Native Framework Mapping
- Location -> CoreLocation
- Health -> HealthKit
- Notifications -> UserNotifications
- Camera -> AVFoundation
- Photos -> PhotosUI / Photos framework
- Canvas -> PencilKit or custom drawing feature

## Important Restrictions to Respect Later
- camera is foreground-only
- health access must be granular and explicit
- always-on location authorization is sensitive and should not be the default ask
- push delivery requires backend/APNs support
- background sync is opportunistic on iOS and should not be misrepresented as guaranteed realtime

## UI Behavior Recommendations
### Authorized
Show calm confirmation and optional summary text.

### Limited
Explain what is available and that broader access can be changed later.

### Denied
Offer an “Open Settings” path rather than repeatedly prompting.

### Not Determined
Offer a first-time explanatory request action.

## Future Policy Layer
When backend wiring is added, permission approval should still remain device/user mediated. Hermes should not be treated as having unrestricted direct access to all device data.

The later backend policy model should likely map to scoped permissions such as:
- `location.read.latest`
- `health.read.steps`
- `health.read.sleepSummary`
- `notifications.send`
- `camera.capture.userInitiated`
- `photos.read.selected`

## Acceptance Criteria for Phase 1
- all permission types render correctly
- statuses are easy to scan
- copy feels privacy-safe and product-ready
- request/open-settings actions never break the app
