---
id: global-gs1
name: GS1 (Verified by GS1, GEPIR)
scope: global
category: product-data
operator: GS1 AISBL and member organisations
access: [api-partner]
auth: oauth2
data: [products]
item_level: true
cost: paid
user_base: Brand owners worldwide; authoritative GTIN registry
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# GS1 (Verified by GS1, GEPIR)

GS1 is the barcode standards body. Verified by GS1 is the authoritative brand-owner product data service; GEPIR tells which company owns a GTIN prefix. High-quality data but gated by GS1 membership/partnership.

## Access

- **api-partner** - Verified by GS1 API and GS1 Data Hub/Cloud via national GS1 member orgs (e.g. GS1 Norway); access requires a licence/agreement (unverified details per country).
- GEPIR (`gepir.gs1.org`) - look-up by GTIN/GLN returns the licensee company only, not product data; manual use is rate limited and automated scraping is discouraged (unverified).

## Data

Verified by GS1: GTIN, brand, product name, net content, image, GPC category, country of sale. GEPIR: company name/address of the GTIN prefix holder.

## FoodSavr mapping

Authoritative name/brand/net-content enrichment if a partner agreement exists; otherwise use OFF and aggregators.

## Risks and constraints

- Commercial licence per country; cost and terms unverified.
- Not suitable for a free app unless via a data partner.

## Existing work

- No open-source clients; some aggregators resell GS1-derived data.

## Sources

- https://www.gs1.org/services/verified-by-gs1 - Verified by GS1
- https://www.gs1.org/services/gepir - GEPIR
