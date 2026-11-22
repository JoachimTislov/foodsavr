---
id: gb-sainsburys
name: Sainsbury's and Nectar
scope: gb
category: online-grocery
operator: J Sainsbury plc
access: [mcp, api-private, export, bot]
auth: username-password
data: [orders, prices, offers]
item_level: true
cost: free
user_base: Second-largest UK grocer; Nectar ~19M members (unverified)
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Sainsbury's and Nectar

Sainsbury's groceries online plus Nectar loyalty. Community tools use the undocumented site API for search, basket and order history.

## Access

- **mcp** — `henryjcee/sainsburys-mcp` (fills basket, never orders), `jbeshir/supermarkets-uk-mcp` (prices), `abracadabra50/uk-grocery-cli` (CLI/MCP).
- **api-private** — undocumented site API.
- **export** — Nectar/GDPR data request (unverified).
- **bot** — Apify scrapers (public catalogue).

## Data

Past online orders include items, quantities, prices (unverified in each client). Product data includes name, price, unit price.

## FoodSavr mapping

Online orders to purchases/`LineItem`; basket fill supports shopping-list export.

## Risks and constraints

Unofficial community tooling for UK supermarkets exists; none of the major retailers publishes a developer API. Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

See Access.

## Sources

- https://github.com/abracadabra50/uk-grocery-cli — via https://awesome.ecosyste.ms/projects/github.com%2Fabracadabra50%2Fuk-grocery-cli
- https://claudemarketplaces.com/mcp/io.github.jbeshir/supermarkets-uk-mcp — price MCP
- https://apify.com/studio-amba/sainsburys-scraper — scraper
