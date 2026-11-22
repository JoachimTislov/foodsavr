---
id: in-swiggy-instamart
name: Swiggy Instamart
scope: in
category: online-grocery
operator: Swiggy Ltd.
access: [mcp]
auth: oauth2-pkce
data: [orders, products, lists]
item_level: true
cost: partner
user_base: India
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Swiggy Instamart

Swiggy provides an official MCP server for Instamart (and Food, Dineout, Scenes) covering browse, cart and ordering with OAuth 2.1 PKCE over streamable HTTP.

## Access

- **mcp** — `mcp.swiggy.com/im` (docs list 16 tools); production access invite/whitelist; partner contract with rate limits; India only. Manifest repo github.com/Swiggy/swiggy-mcp-server-manifest.

## Data

Tool-level catalogue/cart/order functions; order-history tool presence unverified.

## FoodSavr mapping

If a history tool exists: orders to `LineItem`; else cart-out only.

## Risks and constraints

Whitelist and contract terms.

## Existing work

- Community: jigar-dhulla/swiggy-mcp (Packagist); axlymxp/swiggy-mcp-server (Apify).

## Sources

- https://mcp.swiggy.com/builders/docs/start/what-is-swiggy-mcp/ — servers, auth, access
- https://www.swiggy.com/corporate/?p=16731 — press release
- https://mcp.swiggy.com/builders — builders club
