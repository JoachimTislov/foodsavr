---
id: nl-albert-heijn
name: Albert Heijn
scope: nl
category: online-grocery
operator: Ahold Delhaize
access: [api-private, mcp, export, bot]
auth: oauth2
data: [purchases, line-items, orders, products, offers]
item_level: true
cost: free
user_base: NL #1 grocer; AH Bonuskaart; Appie app with digital receipts
tos_risk: medium
fit: 5
status: researched
last_verified: 2026-11-21
---

# Albert Heijn

Dutch market leader. The Appie app (digital receipts, Bonuskaart) uses a private mobile API; community projects wrap it. The older public product API was removed in 2021.

## Access

- **api-private** — mobile API; jabbink's gist documents app endpoints incl. receipt data; `albert-heijn-wrapper` (Node, GraphQL since 3.0.0); `supermarktconnector` (Python, AH + Jumbo).
- **mcp** — `mrserzhan/ah-mcp` exposes the AH mobile API; tokens refresh automatically.
- **export** — GDPR request / Bonuskaart data (unverified).
- Original `AppiePy` stopped working in June 2021.

## Data

Receipts (kassabonnen) with line items, products with GTIN and prices (client-dependent), bonus offers, orders.

## FoodSavr mapping

Receipts to purchases/`LineItem`; products give EAN for enrichment; Bonus offers to offers.

## Risks and constraints

Unofficial; login via app OAuth flow; breaks on app updates. Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

`RinseV/albert-heijn-wrapper`, `bartmachielsen/supermarktconnector`, `mrserzhan/ah-mcp`, `rkalis/AppiePy` (dead), `RikVanHaaren/ah_shop_api`.

## Sources

- https://github.com/mrserzhan/ah-mcp — MCP server
- https://github.com/RinseV/albert-heijn-wrapper — Node wrapper
- https://pypi.org/project/supermarktconnector — Python connector
- https://github.com/rkalis/AppiePy — archived original
- https://gist.github.com/vehgroshop — app API notes (via search)
