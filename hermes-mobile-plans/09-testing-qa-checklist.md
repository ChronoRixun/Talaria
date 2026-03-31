# Hermes Mobile Frontend MVP Testing and QA Checklist

## Build and Compile
- app builds cleanly
- no missing file references
- no undefined symbols or placeholder types
- previews compile for major screens where practical

## Navigation
- root app opens successfully
- each tab is reachable
- navigation between Chat and Talk Mode works
- Settings can reach Permissions if designed as a nested route

## Chat
- mock conversation loads
- user can type a message
- send button behavior works
- sent message appears immediately
- mock reply flow does not crash
- empty/loading/populated states are coherent if implemented

## Talk Mode
- screen loads correctly
- all key states are representable
- mute toggle works visually
- end session returns to idle or exits cleanly
- transcript preview updates coherently in mock mode

## Permissions
- all capability rows render
- status badges/text are readable
- request/open-settings actions are safe
- denied/limited states render gracefully

## Inbox
- mock items display correctly
- item actions update state
- empty state looks intentional if no items remain

## Settings
- key sections render
- connection info is visible
- at least one setting can be changed
- persisted setting survives relaunch if persistence is implemented

## UX and Visual QA
- light mode looks polished
- dark mode looks polished
- spacing is consistent
- status indicators are understandable
- touch targets are comfortably sized
- no obviously unfinished or broken UI surfaces

## Architecture QA
- views depend on protocols or view models, not hardcoded backend logic
- mock services are centralized
- there are explicit TODO seams for future Hermes integration
- code organization is predictable and easy to continue

## Out of Scope Validation
Confirm the project does not accidentally depend on:
- backend credentials
- working network APIs
- realtime streaming infra
- production HealthKit or CoreLocation pipelines

## MVP Exit Criteria
The app should be believable as the first real Hermes Mobile client shell and should be easy for another coding agent to continue.
