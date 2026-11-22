---
id: global-home-assistant
name: Home Assistant
scope: global
category: smart-home
operator: Open Home Foundation
access: [api-public, mcp]
auth: api-key
data: [lists, inventory]
item_level: false
cost: free
user_base: very large self-hosted community (exact unknown)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Home Assistant

Self-hosted smart-home hub with a documented REST/WebSocket API and a native Shopping List integration. A bridge to many appliances (Bring!, Home Connect, SmartThings) without FoodSavr integrating each.

## Access

- **api-public** — REST and WebSocket APIs with long-lived access tokens; Shopping List and To-do list entities; Bring! integration exists.
- **mcp** — Home Assistant ships an MCP server integration (unverified details).

## Data

Entities and to-do items (summary, status). Fridge sensors where available.

## FoodSavr mapping

`lists` sync via to-do entities; door/temperature events. User must expose their HA instance (remote access, token).

## Risks and constraints

- Requires user to run and expose HA; token handling.

## Existing work

- Large integration ecosystem.

## Sources

- https://developers.home-assistant.io/docs/api/rest/ — REST API
- https://www.home-assistant.io/integrations/home_connect/ — Home Connect integration
