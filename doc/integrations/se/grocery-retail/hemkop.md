---
id: se-hemkop
name: Hemköp (Axfood)
scope: se
category: grocery-retail
operator: Axfood AB
access: [api-private, bot]
auth: bankid
data: [purchases, line-items, products, prices, orders]
item_level: true
cost: free
user_base: Axfood's supermarket chain; Hemköp members (size unknown)
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Hemköp (Axfood)

Axfood's mid-market chain with web shop hemkop.se. Shares the Axfood/Hybris backend with Willys, so Willys tooling is the best lead; see `se-willys`.

## Access

- **api-private** — `khessman/kvitto-willys` and matmetrics: "Willys and Hemköp receipts via BankID", same login and receipt format per README. Visible Chromium needed because of the WAF.
- **api-private (web shop)** — willys-agent targets willys.se only; Hemköp web-shop compatibility unverified.
- **bot** — price data via `ostwilkens/primat-api` (see `se-primat`) covers Hemköp.

## Data

Receipts and prices as for Willys (see `se-willys`).

## FoodSavr mapping

Same as Willys: receipts to line items, prices to enrichment.

## Risks and constraints

WAF/bot protection, private API, BankID user presence.

## Existing work

- https://github.com/khessman/kvitto-willys
- https://github.com/khessman/matmetrics
- https://github.com/kristalalfred/shop-it (basket builder for Mathem, Willys, Hemköp; not reviewed)

## Sources

- https://raw.githubusercontent.com/khessman/matmetrics/HEAD/README.md — shared Willys/Hemköp backend and crate
- https://axfood.com/about-axfood/the-axfood-family/hemkop — chain background
