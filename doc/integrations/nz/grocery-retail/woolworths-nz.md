---
id: nz-woolworths-nz
name: Woolworths NZ (ex-Countdown)
scope: nz
category: grocery-retail
operator: Woolworths New Zealand
access: [api-private, bot]
auth: session-cookie
data: [products, prices]
item_level: true
cost: free
user_base: NZ's largest grocer
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Woolworths NZ (ex-Countdown)

No public API. Community scrapers and a Home Assistant integration use the website API; chain rebranded from Countdown in 2023.

## Access

- **api-private/bot** — Jason-nzd/countdown-scraper; codyc1515/ha-countdown (Home Assistant); maxazure/nz-supermarket-scraper.

## Data

Product prices, store lists.

## FoodSavr mapping

Enrichment; no purchase history found.

## Risks and constraints

Unofficial.

## Existing work

- https://github.com/Jason-nzd/countdown-scraper
- https://github.com/codyc1515/ha-countdown

## Sources

- https://github.com/Jason-nzd/countdown-scraper — scraper
- https://skillsmp.com/creators/maxazure/nz-supermarket-scraper — multi-chain scraper
