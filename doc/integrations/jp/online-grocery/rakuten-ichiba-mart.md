---
id: jp-rakuten-ichiba-mart
name: Rakuten Ichiba / Rakuten Mart
scope: jp
category: online-grocery
operator: Rakuten Group
access: [api-public, bot]
auth: api-key
data: [products, prices]
item_level: true
cost: free
user_base: Japan
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Rakuten Ichiba / Rakuten Mart

Ichiba marketplace has an official product search API. Rakuten Seiyu Netsuper became Rakuten Mart in Aug 2024; no public API for its grocery orders was found.

## Access

- **api-public** — Rakuten Web Service Ichiba APIs (app ID; OAuth2 for private data per docs).
- **bot** — commercial Seiyu scraper vendors.

## Data

Product search with price, JAN code (unverified).

## FoodSavr mapping

Enrichment with JAN barcode (unverified).

## Risks and constraints

Branding rules.

## Existing work

- https://apify.com/jpopendata/japan-rakuten-api

## Sources

- https://webservice.rakuten.co.jp/document — portal
- https://global.rakuten.com/corp/news/press/2024/0807_02.html — rename to Rakuten Mart
- https://apify.com/jpopendata/japan-rakuten-api.md — Apify wrapper
