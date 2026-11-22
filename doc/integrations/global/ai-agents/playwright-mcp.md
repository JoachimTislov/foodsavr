---
id: global-playwright-mcp
name: Playwright MCP
scope: global
category: ai-agents
operator: Microsoft
access: [bot, mcp]
auth: none
data: [orders, prices, products]
item_level: true
cost: free
user_base: developer tool
tos_risk: high
fit: 4
status: researched
last_verified: 2026-11-21
---

# Playwright MCP

Official Playwright MCP server lets an LLM drive a browser through accessibility snapshots. Bot-layer building block for any site.

## Access

- **mcp** — `@playwright/mcp` (npm, Apache-2.0 per repo, unverified); runs locally, headless or headed; can reuse a persistent profile.

## Data

Whatever the user can see in a logged-in browser: order history, cart, prices, product pages. Output is scraped HTML/text, structured by an LLM.

## FoodSavr mapping

Unlocks `bot` access to sites without APIs (retailer order history, loyalty portals). FoodSavr would run it on the user's behalf with their credentials or session; yields `orders`, `LineItem`, `offers`.

## Risks and constraints

- Retailer ToS often prohibit automation; anti-bot measures; credential/session custody; runs outside a phone (needs server or desktop host).

## Existing work

- Playwright ecosystem.

## Sources

- https://github.com/microsoft/playwright-mcp — repo
