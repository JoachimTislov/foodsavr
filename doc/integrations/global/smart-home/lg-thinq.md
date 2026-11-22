---
id: global-lg-thinq
name: LG ThinQ
scope: global
category: smart-home
operator: LG Electronics
access: [api-public, api-private]
auth: oauth2
data: [inventory]
item_level: false
cost: free
user_base: unknown
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# LG ThinQ

LG ThinQ connects LG fridges and appliances. LG offers a ThinQ Connect developer API for devices (unverified scope); fridge food inventory is not known to be exposed.

## Access

- **api-public** — LG ThinQ Connect API with personal access token (unverified details).
- **api-private** — community reverse-engineered app protocol used by Home Assistant integrations (unverified).

## Data

Device state (temperatures, door, mode). No item list found.

## FoodSavr mapping

No inventory mapping beyond door/temperature signals.

## Risks and constraints

- Cloud-only; unverified stability.

## Existing work

- Home Assistant `thinq` integrations (unverified).

## Sources

- https://smartsolution.developer.lge.com/ — LG developer portal (unverified path)
