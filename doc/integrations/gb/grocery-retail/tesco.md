---
id: gb-tesco
name: Tesco and Clubcard
scope: gb
category: grocery-retail
operator: Tesco PLC
access: [export, api-private, bot]
auth: unknown
data: [purchases, offers, prices]
item_level: true
cost: free
user_base: Clubcard has ~20M+ members (unverified); largest UK grocer
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Tesco and Clubcard

UK's largest grocer. The public Tesco developer API (Grocery/Tesco Labs) was discontinued. Clubcard holds in-store purchase history; the app shows Clubcard prices and points.

## Access

- **export** — Clubcard data subject access request (GDPR); in-app history detail unverified.
- **api-private** — reverse-engineered web/app endpoints (an MCP 'Basketeer' automates the user's own account, unverified scope).
- **bot** — scrapers (Apify) for prices and Clubcard offer flags.
- Official: developer.tesco.com Grocery API retired (per third-party summaries); older clients exist.

## Data

No confirmed programmatic access to Clubcard purchase history. Product search APIs formerly returned name, EAN, price, nutrition (old clients).

## FoodSavr mapping

Online grocery orders (item-level) and Clubcard prices map to purchases/offers. In-store purchases need export.

## Risks and constraints

Terms of service restrict automated access (unverified). Anti-bot protections strong. Clubcard app changes (2024) altered the app landscape.

## Existing work

`moreati/tescolabsapi`, `ImClarky/tesco-api-php` (both for retired API), `jbeshir/supermarkets-uk-mcp` (prices), `abracadabra50/uk-grocery-cli` (Tesco in progress).

## Sources

- https://awesome.ecosyste.ms/projects/github.com%2Fmoreati%2Ftescolabsapi — old API client
- https://packagist.org/packages/imclarky/tesco-api — PHP client
- https://mcpservers.org/servers/tobyandrews1985/basketeer — MCP
- https://www.which.co.uk/news/article/tesco-clubcard-and-pay-app-changes-a5ZCO0W0SlC7 — Clubcard app changes
- https://parse.bot/marketplace/07b466cc-ad41-4625-8ee0-b278c24a8c18/tesco-com-api — third-party note on API retirement
