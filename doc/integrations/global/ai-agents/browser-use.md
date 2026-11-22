---
id: global-browser-use
name: Browser Use
scope: global
category: ai-agents
operator: Browser Use
access: [bot, mcp]
auth: none
data: [orders, prices, products]
item_level: true
cost: freemium
user_base: developer tool
tos_risk: high
fit: 4
status: researched
last_verified: 2026-11-21
---

# Browser Use

Open-source Python library and cloud for LLM-driven web agents.

## Access

- **mcp** — library plus MCP server (verify); cloud offering with per-hour browser rate (third-party reports, unverified).

## Data

Whatever the user can see in a logged-in browser: order history, cart, prices, product pages. Output is scraped HTML/text, structured by an LLM.

## FoodSavr mapping

Unlocks `bot` access to sites without APIs (retailer order history, loyalty portals). FoodSavr would run it on the user's behalf with their credentials or session; yields `orders`, `LineItem`, `offers`.

## Risks and constraints

- Site ToS and anti-bot; LLM cost per task.

## Existing work

- Open-source (licence unverified).

## Sources

- https://github.com/browser-use/browser-use — repo
