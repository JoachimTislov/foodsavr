---
id: global-siri-shortcuts
name: Siri Shortcuts and App Intents
scope: global
category: smart-home
operator: Apple
access: [api-public]
auth: none
data: [lists, inventory]
item_level: false
cost: free
user_base: all iOS/macOS users
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Siri Shortcuts and App Intents

FoodSavr can expose App Intents so users add items to FoodSavr by voice ("Hey Siri, add oat milk to FoodSavr") or via Shortcuts automations. Inbound only.

## Access

- **api-public** — App Intents framework / SiriKit; Shortcuts actions are exposed automatically to the Shortcuts app. Requires native iOS code in the Flutter app (unverified plugin options).

## Data

Parameters supplied by the user: item text, quantity, optional date.

## FoodSavr mapping

Creates `lists` or pantry (`inventory`) entries. Combined with Apple Reminders, can bridge shared lists.

## Risks and constraints

- iOS only; development effort in native layer.

## Existing work

- Native iOS pattern; no Flutter-specific packages verified.

## Sources

- https://developer.apple.com/documentation/appintents — App Intents
- https://developer.apple.com/documentation/sirikit — SiriKit
