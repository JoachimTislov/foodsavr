---
id: global-apple-reminders
name: Apple Reminders
scope: global
category: shopping-lists
operator: Apple
access: [api-public, export]
auth: none
data: [lists]
item_level: false
cost: free
user_base: all iOS/macOS users
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Apple Reminders

Apple's built-in list app, commonly used for shared grocery lists. No cloud REST API; access is on-device through EventKit or Shortcuts.

## Access

- **api-public** — EventKit (`EKReminder`) on iOS/macOS with user permission; usable from Flutter through a native plugin (package choice unverified).
- **export** — Shortcuts actions (Find/Add Reminders) can move items to or from FoodSavr via App Intents or URL scheme.

## Data

Reminders lists with title, notes, completion, due date. Shared iCloud lists. Free text.

## FoodSavr mapping

`lists` two-way on-device only (iOS/macOS). No server-side sync.

## Risks and constraints

- On-device only; no Android or web access.
- Requires Reminders permission prompt.

## Existing work

- Native Flutter plugins exist (unverified).

## Sources

- https://developer.apple.com/documentation/eventkit — EventKit
- https://support.apple.com/guide/shortcuts/welcome/ios — Shortcuts
