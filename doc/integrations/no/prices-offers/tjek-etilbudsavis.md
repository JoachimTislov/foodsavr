---
id: no-tjek-etilbudsavis
name: Tjek (eTilbudsavis, Mattilbud, eReklamblad)
scope: no
category: prices-offers
operator: Tjek A/S (Copenhagen)
access: [api-partner, bot]
auth: unknown
data: [offers]
item_level: true
cost: partner
user_base: Tjek says it reaches about 1 million people per month in Norway
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Tjek (eTilbudsavis / Mattilbud)

Tjek publishes digital grocery flyers and offers. In Norway its consumer apps are sold as eTilbudsavis, eReklamblad and Mattilbud; Mattilbud is the same operator, so no separate entry. FoodSavr would get weekly chain offers (Rema, Coop, Kiwi, Bunnpris etc., chain coverage unverified).

## Access

- **api-partner** — Tjek's APIs page states they serve its publication data through APIs and directs interested parties to services@tjek.com. No self-serve developer portal or public docs found.
- **bot** — third-party vendors (e.g. Actowiz) market scraping of Mattilbud data; not an official route.

## Data

Flyer/publication pages and offers (Incito format). Field-level schema unknown (unverified).

## FoodSavr mapping

Offers only: match flyer offers to shopping-list items. Alternative offer source with public API: `kassal-app.md`.

## Risks and constraints

- Commercial agreement required; terms unknown.
- Scraping likely breaches ToS and Danish/Norwegian database rights (unverified).

## Existing work

Apify/Actowiz scrapers exist for Mattilbud and Tjek-Denmark sites; no official SDK found. No MCP server found.

## Sources

- https://tjek.com/apis-and-sdks — API contact route
- https://tjek.com/apps — brand list (eTilbudsavis, Mattilbud, eReklamblad)
- https://www.actowizsolutions.com/mattilbud-grocery-pricing-data-scraping.php — scraping vendor
