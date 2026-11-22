---
id: global-claude-computer-use
name: Claude computer use
scope: global
category: ai-agents
operator: Anthropic
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

# Claude computer use

Anthropic's computer-use tool lets Claude operate a desktop or browser via screenshots and mouse/keyboard actions. Heavier than DOM-based agents but works in any app.

## Access

- **api-public** — computer-use tool in the Claude API (beta; check docs). Also available through Claude in Chrome and desktop products.

## Data

Whatever the user can see in a logged-in browser: order history, cart, prices, product pages. Output is scraped HTML/text, structured by an LLM.

## FoodSavr mapping

Unlocks `bot` access to sites without APIs (retailer order history, loyalty portals). FoodSavr would run it on the user's behalf with their credentials or session; yields `orders`, `LineItem`, `offers`.

## Risks and constraints

- Token cost per run; slower; ToS of target sites; sandboxing required.

## Existing work

- Reference implementation in Anthropic docs.

## Sources

- https://docs.claude.com/en/docs/agents-and-tools/tool-use/computer-use-tool — computer use docs
