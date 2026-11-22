---
id: global-skyvern
name: Skyvern
scope: global
category: ai-agents
operator: Skyvern
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

# Skyvern

LLM + computer-vision browser automation, workflow-oriented; self-host (reported AGPL-3.0, verify) or Skyvern Cloud.

## Access

- **mcp** — Skyvern provides API/SDK and an MCP server (verify); cloud usage-based.

## Data

Whatever the user can see in a logged-in browser: order history, cart, prices, product pages. Output is scraped HTML/text, structured by an LLM.

## FoodSavr mapping

Unlocks `bot` access to sites without APIs (retailer order history, loyalty portals). FoodSavr would run it on the user's behalf with their credentials or session; yields `orders`, `LineItem`, `offers`.

## Risks and constraints

- AGPL obligations if self-hosted and modified (verify licence).

## Existing work

- Open-source with cloud.

## Sources

- https://github.com/Skyvern-AI/skyvern — repo
- https://skyvern.com/blog/stagehand-alternatives-pricing-reviews/ — vendor comparison (biased source)
