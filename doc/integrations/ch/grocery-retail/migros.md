---
id: ch-migros
name: Migros (Cumulus)
scope: ch
category: grocery-retail
operator: Migros-Genossenschafts-Bund
access: [api-private, export, mcp]
auth: oidc
data: [purchases, line-items, offers]
item_level: true
cost: free
user_base: Switzerland #1 retailer; Cumulus ~ most households
tos_risk: medium
fit: 5
status: researched
last_verified: 2026-11-21
---

# Migros (Cumulus)

Swiss retailer whose Cumulus programme keeps digital receipts. Migros staff say there is no public API. Community projects read receipts from cumulus.migros.ch.

## Access

- **api-private** — `migros-api-wrapper` (npm) documents login.migros.ch/cumulus.migros.ch endpoints incl. receipt export; `cstuder/cumulizer` aggregates Cumulus receipts.
- **mcp** — `nicktcode/swissgroceries-mcp` (Migros and Coop).
- **export** — Cumulus receipts/CSV export (unverified).

## Data

Receipts with items (name, quantity, price); in-store scanned.

## FoodSavr mapping

Receipts to purchases/`LineItem`; EAN unverified.

## Risks and constraints

No public API (official forum). Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

`migros-api-wrapper`, `IAmQuiteHungry` (login), `cstuder/cumulizer`, `nicktcode/swissgroceries-mcp`.

## Sources

- https://migipedia.migros.ch/en/forum/cumulus/api-for-receipt-items — official forum reply
- https://migipedia.migros.ch/en/forum/cumulus/public-api-fuer-eigene-kundendaten — API request thread
- https://cdn.jsdelivr.net/npm/migros-api-wrapper@1.1.37/README.md — wrapper README
- https://make.opendata.ch/wiki/_export/xhtml/project:cumulizer — cumulizer
- https://awesome.ecosyste.ms/projects/github.com%2Fnicktcode%2Fswissgroceries-mcp — MCP
