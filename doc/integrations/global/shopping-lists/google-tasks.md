---
id: global-google-tasks
name: Google Tasks
scope: global
category: shopping-lists
operator: Google
access: [api-public]
auth: oauth2
data: [lists]
item_level: false
cost: free
user_base: very large (bundled with Gmail/Calendar)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Google Tasks

Task lists inside Gmail/Calendar/Google apps. Documented REST API; the practical Google-account list sync target since Keep's API is enterprise-only.

## Access

- **api-public** — Google Tasks API v1 (`tasks.googleapis.com`); OAuth2 scopes `tasks` / `tasks.readonly`.

## Data

Task lists and tasks (title, notes, due, status, parent). Free text.

## FoodSavr mapping

`lists` two-way; quantity parsing from title. No purchase signal.

## Risks and constraints

- OAuth consent verification may be required for production (unverified).
- Low ToS risk.

## Existing work

- Official client libraries (Dart, JS, Python).

## Sources

- https://developers.google.com/tasks — Tasks API docs
