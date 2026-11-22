---
id: in-zomato
name: Zomato (Eternal)
scope: in
category: food-delivery
operator: Eternal Limited
access: [mcp]
auth: oauth2
data: [orders]
item_level: false
cost: unknown
user_base: India
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Zomato (Eternal)

Zomato publishes an official MCP server manifest; no current public REST developer programme found.

## Access

- **mcp** — `https://mcp-server.zomato.com/mcp` (manifest github.com/zomato/mcp-server-manifest); discovery, cart, order tracking, QR payment; OAuth.
- Legacy REST API policy dated 2020 (unverified current).

## Data

Restaurant search, cart, orders.

## FoodSavr mapping

Orders as consumption events; history unverified.

## Risks and constraints

Terms unreviewed.

## Existing work

- https://mcpservers.org/servers/zomato-mcp

## Sources

- https://mcpservers.org/servers/zomato-mcp — MCP listing
- https://claude.com/connectors/zomato — connector page
