---
id: gb-iceland
name: Iceland Foods
scope: gb
category: grocery-retail
operator: Iceland Foods Ltd
access: [bot, export]
auth: unknown
data: [purchases, offers]
item_level: false
cost: unknown
user_base: UK frozen-food chain; Bonus Card
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Iceland Foods

Iceland Foods grocery chain in the UK. No public developer API found. Possible data: online orders, membership purchase history, offers.

## Access

- **bot** — price scrapers cover public catalogue where listed under Existing work.
- **export** — GDPR/GDPR-style data-access request (Art. 15/20) to the operator; format and item-level detail vary and delivery can take up to a month (unverified per operator).

## Data

Not verified. Loyalty-app purchase history, where offered, is typically per-visit with line items (unverified). No public schema found.

## FoodSavr mapping

Purchases/orders to `LineItem` where line items are exposed; offers to the offers class. EAN availability unknown. No expiry data; FoodSavr would estimate shelf life from product category.

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR. Official public API: none found.

## Existing work

None found (unverified).

## Sources

- https://claudemarketplaces.com/mcp/io.github.jbeshir/supermarkets-uk-mcp — UK supermarkets price MCP (check store coverage)
- https://apify.com/jupri/asda-scraper/api/mcp — Asda scraper (Asda entry)
