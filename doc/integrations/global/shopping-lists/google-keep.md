---
id: global-google-keep
name: Google Keep
scope: global
category: shopping-lists
operator: Google
access: [api-public, bot]
auth: oauth2
data: [lists]
item_level: false
cost: free
user_base: very large (consumer app)
tos_risk: medium
fit: 1
status: researched
last_verified: 2026-11-21
---

# Google Keep

Note and checklist app. The official Keep API targets Workspace enterprise administrators only, so consumer integration is not supported.

## Access

- **api-public** — `keep.googleapis.com` v1: notes create/get/list/delete, permissions, attachment download; aimed at Workspace enterprise admins (security tooling), not consumer apps.
- **bot** — unofficial `gkeepapi` (Python) uses private protocol with Google credentials; fragile (current status unverified).

## Data

Notes with text or list items, attachments, permissions.

## FoodSavr mapping

Could map to `lists` for Workspace tenants only; the consumer path is unofficial.

## Risks and constraints

- Official API requires Workspace admin setup.
- Unofficial clients risk account lockout.

## Existing work

- kiwiz/gkeepapi (Python, unofficial)

## Sources

- https://developers.google.com/workspace/keep/api/guides — Keep API overview
- https://developers.google.com/workspace/keep/release-notes — release notes
- https://github.com/kiwiz/gkeepapi — unofficial client
