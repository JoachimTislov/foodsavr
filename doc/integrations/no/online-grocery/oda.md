---
id: no-oda
name: Oda (ex Kolonial.no)
scope: no
category: online-grocery
operator: Oda Norway AS
access: [api-private, mcp, bot]
auth: username-password
data: [orders, line-items, products, prices, recipes, lists]
item_level: true
cost: unknown
user_base: Norway online-only grocer (also Finland, Germany exit; Norway is core); size unknown
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Oda (ex Kolonial.no)

Norwegian online-only grocery retailer. Account holders have order history, saved lists and recipes; FoodSavr could ingest past orders as purchases with item-level detail.

## Access

- **api-private** — Oda web/app JSON API under `oda.com/no/api/v1/`. Official [kolonialno/api-docs](https://github.com/kolonialno/api-docs) states the API is not publicly available; an older wrapper says contact Kolonial for access. Public search endpoint `oda.com/api/v1/search/mixed/` is read by third-party scrapers (per Apify listing).
- **mcp** — community `gbbirkisson/mcp-oda`: login with Oda credentials (session stored locally); product search, recipes, saved lists, purchase history (partial: most-frequent products), cart, read-only delivery slots. README marks the project deprecated.
- **bot** — fallback via browser automation on the user's session (unverified need).

## Data

Products, prices, order/purchase history, lists, recipes. Oda's API reportedly does not publish EAN/GTIN (per Apify scraper description). Full past-order detail beyond frequent products is (unverified).

## FoodSavr mapping

Orders -> purchases with `LineItem` per product; name/quantity/price known, no EAN so matching needs name or Oda product-id mapping. Delivery date gives purchase date; expiry must be estimated by category. Recipes could feed meal plans; lists could sync.

## Risks and constraints

- No public API; private endpoints can change without notice.
- Credential-based login (no OAuth) means FoodSavr would hold user passwords or tokens.
- Terms-of-service stance on automated access not checked (unverified).

## Existing work

- [gbbirkisson/mcp-oda](https://github.com/gbbirkisson/mcp-oda) — MCP/CLI, deprecated.
- [frefrik/python-kolonial](https://awesome.ecosyste.ms/projects/github.com%2Ffrefrik%2Fpython-kolonial) — Python wrapper, last push Dec 2020.
- [khaffner/kolonial](https://github.com/khaffner/kolonial) — wrapper requiring API access.
- [jens-ox/oda](https://github.com/jens-ox/oda) — nightly public catalogue dump.
- [Apify oda-scraper](https://apify.com/studio-amba/oda-scraper) — public search scraper.

## Sources

- [kolonialno/api-docs](https://github.com/kolonialno/api-docs) — API not public.
- [gbbirkisson/mcp-oda](https://github.com/gbbirkisson/mcp-oda) — MCP capabilities.
- [Apify oda-scraper](https://apify.com/studio-amba/oda-scraper) — search endpoint, no EAN.
- [khaffner/kolonial](https://github.com/khaffner/kolonial)
- [awesome.ecosyste.ms python-kolonial](https://awesome.ecosyste.ms/projects/github.com%2Ffrefrik%2Fpython-kolonial)
- [jens-ox/oda](https://github.com/jens-ox/oda)
