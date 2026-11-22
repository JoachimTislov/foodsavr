---
id: global-samsung-smartthings
name: Samsung Family Hub and SmartThings
scope: global
category: smart-home
operator: Samsung
access: [api-public, api-partner]
auth: oauth2
data: [inventory]
item_level: false
cost: free
user_base: SmartThings tens of millions of users (vendor claim, unverified)
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Samsung Family Hub and SmartThings

SmartThings has a public REST API for connected devices. Family Hub fridge features (food manager, inside cameras) are in the Samsung app; whether food inventory is exposed in the API was not found.

## Access

- **api-public** — SmartThings API with OAuth2/personal access tokens; device capabilities and status (fridge temperature, door). Food Manager data not found in capabilities (unverified).
- **api-partner** — Family Hub food-management partner programs are unclear (unverified).

## Data

Device status and capabilities (door open, temperature, power); no confirmed item list.

## FoodSavr mapping

Door-open and temperature events only; no inventory unless Samsung exposes it.

## Risks and constraints

- Fridge food inventory unconfirmed.
- API terms and token lifetimes change (unverified).

## Existing work

- Home Assistant SmartThings integration (unverified).

## Sources

- https://developer.smartthings.com/docs/api/public — SmartThings API
