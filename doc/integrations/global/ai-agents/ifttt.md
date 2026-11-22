---
id: global-ifttt
name: IFTTT
scope: global
category: ai-agents
operator: IFTTT Inc.
access: [api-public, mcp]
auth: oauth2
data: [lists, orders, purchases]
item_level: false
cost: freemium
user_base: unknown
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# IFTTT

Applet platform with a service-builder program; relevant to Bosch Home Connect fridge cameras and Alexa/Google triggers.

## Access

- **api-partner** — IFTTT Service Builder / Connect API; pro tier required for publishing (unverified).

## Data

Whatever trigger/action apps expose: webhooks and connectors for Gmail, Sheets, Todoist, Telegram etc.

## FoodSavr mapping

Glue: lets users wire FoodSavr webhooks to hundreds of apps without FoodSavr building each integration; FoodSavr would expose a webhook/trigger endpoint and optionally a platform app.

## Risks and constraints

- Limited free applets; platform direction uncertain.

## Existing work

- Mature ecosystems.

## Sources

- https://ifttt.com/connect/hc_fridge/simcam — Home Connect fridge camera on IFTTT
