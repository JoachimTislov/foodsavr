---
id: global-bosch-home-connect
name: Bosch Home Connect
scope: global
category: smart-home
operator: BSH Hausgeräte GmbH
access: [api-public]
auth: oauth2
data: [inventory]
item_level: false
cost: free
user_base: Bosch/Siemens/Neff/Gaggenau owners, mainly Europe (unverified)
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Bosch Home Connect

Home Connect has a documented REST API for connected appliances (fridge freezers included). Consumer-app fridge camera and inventory list appear in marketing only; no camera or inventory endpoint was found in the API.

## Access

- **api-public** — developer.home-connect.com; OAuth2 authorization code; REST + server-sent events; supported appliance types include Fridge Freezer and Refrigerator (FAQ). Simulator available.

## Data

Appliance status, settings (setpoints, door state, light), events. No images or food list found.

## FoodSavr mapping

No inventory data. Only door/temperature events. Fridge camera images are not available via the API (unverified absence).

## Risks and constraints

- Developer app registration; rate limits apply (unverified).

## Existing work

- Home Assistant `home_connect` integration; homebridge-homeconnect.

## Sources

- https://developer.home-connect.com/support/faq — supported appliance types
- https://developer.home-connect.com/changelog — API changes
- https://www.home-assistant.io/integrations/home_connect/ — fridge entities
- https://www.bosch-home.com/sa/en/experience-bosch/homeconnect/homeconnect-fridges — consumer features
