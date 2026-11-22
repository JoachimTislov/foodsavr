---
id: se-matpriskollen
name: Matpriskollen
scope: se
category: prices-offers
operator: Matpriskollen (legal entity unverified)
access: [api-private, mcp, bot]
auth: none
data: [prices, offers]
item_level: true
cost: free
user_base: Swedish grocery price comparison app; claims data from about 3,200 stores
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Matpriskollen

Price comparison across Swedish grocery chains: store prices, weekly offers, shopping lists. No official developer API found.

## Access

- **api-private / bot** — `Oskmey/aiomatpriskollen` (async Python client: stores, weekly offers, product prices; README gives no endpoints). `kyngvesson/matpriskollen-mcp` scrapes web.matpriskollen.se offers per configured store (a store-selection cookie plus a store UUID).
- **mcp** — `kyngvesson/matpriskollen-mcp`, `arvind0212/matpriskollen-personal-mcp` (not reviewed).
- Home Assistant: `TimmyUll/ha-matpriskollen`.

## Data

Store list, weekly offers, product prices per store.

## FoodSavr mapping

Offers input class; price comparison on shopping-list items.

## Risks and constraints

Scraping a service whose business is the data; terms not reviewed. `se-primat` is a documented alternative.

## Existing work

- https://github.com/Oskmey/aiomatpriskollen
- https://github.com/kyngvesson/matpriskollen-mcp
- https://github.com/TimmyUll/ha-matpriskollen

## Sources

- https://github.com/kyngvesson/matpriskollen-mcp — scraping approach and config
- https://github.com/Oskmey/aiomatpriskollen — Python client
- https://web.matpriskollen.se/ — service
