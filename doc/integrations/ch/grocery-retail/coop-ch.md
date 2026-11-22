---
id: ch-coop-ch
name: Coop (Switzerland) and Supercard
scope: ch
category: grocery-retail
operator: Coop Genossenschaft
access: [mcp, api-private, export]
auth: unknown
data: [purchases, products, prices]
item_level: true
cost: free
user_base: Switzerland #2 retailer; Supercard
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Coop (Switzerland) and Supercard

Swiss grocer with Supercard loyalty and app. Product/price tooling exists via `swissgroceries-mcp`; purchase history API not verified.

## Access

- **mcp** — `nicktcode/swissgroceries-mcp` covers Migros and Coop; maintainer notes endpoints are unofficial.
- **export** — Supercard data request (unverified).

## Data

Unknown for receipts.

## FoodSavr mapping

Products and prices; purchases if exported.

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

`nicktcode/swissgroceries-mcp`. Not to be confused with Coop Norway/Denmark/Sweden.

## Sources

- https://awesome.ecosyste.ms/projects/github.com%2Fnicktcode%2Fswissgroceries-mcp — MCP
