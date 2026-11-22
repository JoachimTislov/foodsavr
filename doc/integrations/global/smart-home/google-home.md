---
id: global-google-home
name: Google Assistant and Google Home
scope: global
category: smart-home
operator: Google
access: [api-public, none]
auth: oauth2
data: [lists]
item_level: false
cost: free
user_base: very large
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Google Assistant and Google Home

Google Home/Assistant lets users add items to lists by voice. No documented public API reads Assistant shopping lists (the old Assistant shopping list moved to Google Keep/Tasks, unverified).

## Access

- **api-public** — Google Home APIs and Smart Home Actions cover device control, not shopping lists. Voice-added lists end up in Google Keep or Tasks (unverified); see Google Tasks and Keep entries.
- **none** — no direct Assistant list API found.

## Data

No list data via Home APIs.

## FoodSavr mapping

Indirect: sync via Google Tasks if the user's lists live there.

## Risks and constraints

- Conversational Actions were shut down in 2023 (unverified); do not plan on Assistant actions.

## Existing work

- None located.

## Sources

- https://developers.home.google.com/ — Google Home developer docs
