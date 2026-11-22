---
id: global-browserbase-stagehand
name: Browserbase and Stagehand
scope: global
category: ai-agents
operator: Browserbase
access: [bot, mcp]
auth: none
data: [orders, prices, products]
item_level: true
cost: paid
user_base: developer tool
tos_risk: high
fit: 4
status: researched
last_verified: 2026-11-21
---

# Browserbase and Stagehand

Stagehand is an MIT-licensed SDK adding natural-language `act/extract/observe` to browser automation; Browserbase is the hosted managed-browser cloud it runs on.

## Access

- **mcp** — Browserbase MCP server (verify); Stagehand SDK local or on Browserbase cloud. Cloud billed per session (third-party reports $99/mo plans, unverified; see Browserbase pricing).

## Data

Whatever the user can see in a logged-in browser: order history, cart, prices, product pages. Output is scraped HTML/text, structured by an LLM.

## FoodSavr mapping

Unlocks `bot` access to sites without APIs (retailer order history, loyalty portals). FoodSavr would run it on the user's behalf with their credentials or session; yields `orders`, `LineItem`, `offers`.

## Risks and constraints

- Cloud hosts user sessions: credential and GDPR implications; site ToS.

## Existing work

- Stagehand open-source.

## Sources

- https://www.browserbase.com/pricing — cloud pricing
- https://github.com/browserbase/stagehand — SDK
