---
id: dk-nemlig
name: Nemlig.com
scope: dk
category: online-grocery
operator: Nemlig.com A/S
access: [api-private, bot]
auth: username-password
data: [orders, line-items, products, prices]
item_level: true
cost: free
user_base: Denmark's main pure online grocer (size unverified)
tos_risk: high
fit: 5
status: researched
last_verified: 2026-11-21
---

# Nemlig.com

Danish online supermarket. Order history gives item lists with quantities, so it is a strong inventory source. No official API; community clients use the site's undocumented REST API.

## Access

- **api-private** — [schourode/nemlig](https://github.com/schourode/nemlig): Python shopping robot over a non-advertised REST API found by network inspection; lists previous orders and adds to basket. [lordmike/mbw.nemlig2mqtt](https://awesome.ecosyste.ms/projects/github.com%2Flordmike%2Fmbw.nemlig2mqtt): MQTT/Home Assistant bridge (prototype, reverse-engineered API). Login flow details unverified; presumably user email and password.
- **bot** — [lordmike/mbw.script.nemligorders](https://awesome.ecosyste.ms/projects/github.com%2Flordmike%2Fmbw.script.nemligorders): browser-console script dumping order history to `orders.json`.
- Apify scrapers ([Nemlig Scraper](https://apify.com/blackfalcondata/nemlig-scraper.md)) cover products and prices, not orders.
- No official developer API or MCP server found.

## Data

Orders with line items (name, quantity, price). EAN presence unverified.

## FoodSavr mapping

Order to purchase; lines to `LineItem`. Delivery date approximates purchase date. No expiry data (unverified whether product pages show shelf life).

## Risks and constraints

ToS likely forbids automated access; private endpoints can change; needs user credentials.

## Existing work

Repos above; maintenance not checked.

## Sources

- https://github.com/schourode/nemlig
- https://awesome.ecosyste.ms/projects/github.com%2Flordmike%2Fmbw.nemlig2mqtt
- https://awesome.ecosyste.ms/projects/github.com%2Flordmike%2Fmbw.script.nemligorders
- https://apify.com/blackfalcondata/nemlig-scraper.md
