---
id: dk-salling-food-waste-api
name: Salling Group Food Waste API
scope: dk
category: food-waste
operator: Salling Group A/S
access: [api-public, mcp]
auth: api-key
data: [offers, prices, products]
item_level: true
cost: free
user_base: Netto, Føtex, Bilka and Basalt stores in Denmark; official API
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Salling Group Food Waste API

Official API listing food heavily discounted in stores because of short remaining shelf life. The near-expiry flag is built in. FoodSavr could surface "cheap, use soon" items near the user.

## Access

- **api-public** — Part of the Salling developer portal. Lookups by ZIP code, by geolocation plus radius, and by store id; Bearer token required. ([API reference](https://developer.sallinggroup.com/api-reference), [portal](https://developer.sallinggroup.dev/?from-old=true))
- **mcp** — Community MCP server [Kristoffer88/salling-food-waste-mcp](https://github.com/Kristoffer88/salling-food-waste-mcp) (tools `search_food_waste`, `get_store_food_waste`; hosted endpoint limited to 10 req/min per client; Glama lists it as inactive). ([Glama](https://glama.ai/mcp/servers/ghz1uj08ys))

## Data

Per store: discounted products with prices and expiry-related info. Exact field list (EAN, discount, stock, end time) was not readable (unverified).

## FoodSavr mapping

Offers class. Match to shopping-list items by name or EAN. A markdown implies imminent expiry, so a bought item could default to a short shelf life (heuristic, unverified).

## Risks and constraints

Free key; terms and rate limits unverified. Denmark only. Stock changes quickly.

## Existing work

- [mikkelkrogsholm/salling-food-waste skill](https://skills.sh/mikkelkrogsholm/skills/salling-food-waste) — Bun CLI, key via `SALLING_API_KEY`.
- [larsdpeder/Salling-Group-Food-Waste-Finder](https://tgfed.nhyvvfeijnh.workers.dev/larsdpeder/Salling-Group-Food-Waste-Finder) — Python script (mirror link).
- MCP server above.

## Sources

- https://developer.sallinggroup.com/api-reference
- https://glama.ai/mcp/servers/ghz1uj08ys
- https://skills.sh/mikkelkrogsholm/skills/salling-food-waste
