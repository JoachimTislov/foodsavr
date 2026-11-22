---
id: global-go-upc
name: Go-UPC
scope: global
category: product-data
operator: Go-UPC
access: [api-public]
auth: api-key
data: [products]
item_level: true
cost: freemium
user_base: Global UPC/EAN lookup
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Go-UPC

Barcode lookup API (UPC/EAN/ISBN) with a free tier and paid plans. Returns name, brand, category, description, image, specs.

## Access

- **api-public** - `https://go-upc.com/api/v1/code/{code}` with Bearer API key; tiered plans.

## Data

`product`: `name`, `description`, `region`, `brand`, `category`, `imageUrl`, `specs`; occasional `ingredients`.

## FoodSavr mapping

Fallback enrichment after OFF.

## Risks and constraints

- Quotas per plan; terms unverified.

## Existing work

- No MCP server found.

## Sources

- https://go-upc.com/api - API page
