---
id: se-coop-sverige
name: Coop Sverige
scope: se
category: grocery-retail
operator: Coop Sverige AB
access: [bot, export]
auth: unknown
data: [products, prices, purchases]
item_level: true
cost: unknown
user_base: One of Sweden's largest grocery groups; Coop member app (size unknown)
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Coop Sverige

Swedish consumer co-operative grocer (Coop, Stora Coop, Extra). This entry covers Coop Sverige only, not Coop Norway. No official developer API and no documented unofficial API for member purchase history was found.

## Access

- **bot / public search API** — coop.se's search box calls a JSON API directly; an Apify actor says the subscription key is shipped in cleartext in the page HTML and that it returns products, prices, brands and EANs without login (not verified by me).
- **export** — Coop announced digital receipts for members, first in Scan & Pay, later coop.se and the app (Eurocoop note, undated). Whether receipts go through Kivra is unconfirmed.
- No reverse-engineered Swedish member API found. The Norwegian "Coop medlem" app has one (different company; see `no` scope).

## Data

Product name, price, brand, EAN via the search API; member purchase history format unknown.

## FoodSavr mapping

Enrichment and price lookup (EAN) now; purchases only if digital receipts become reachable.

## Risks and constraints

- Cloudflare in front of coop.se; using an embedded key may breach terms.
- No stable contract.

## Existing work

- https://apify.com/studio-amba/coop-se-scraper
- https://github.com/Esspel/ha_coop_sverige (Home Assistant integration; not reviewed)
- https://github.com/ostwilkens/primat-api (daily Coop prices, see `se-primat`)

## Sources

- https://apify.com/studio-amba/coop-se-scraper.md — public search API, EANs, no login
- https://eurocoop.coop/?p=1848 — Coop Sweden digital receipts
- https://gist.github.com/HelgeSverre/80a7f34f874336324184a0c513c2e6a2 — Norwegian Coop only (contrast)
