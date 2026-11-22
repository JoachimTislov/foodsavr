---
id: us-kroger
name: Kroger
scope: us
category: grocery-retail
operator: The Kroger Co.
access: [api-public, api-partner, mcp]
auth: oauth2
data: [products, prices, lists]
item_level: true
cost: free
user_base: Kroger family banners (Fred Meyer, Ralphs, Harris Teeter, etc.), US-wide
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Kroger

Kroger runs an official developer portal with OAuth2. The public API covers product search, store locations, adding items to a shopper's cart and the shopper profile. It does not expose purchase history.

## Access

- **api-public** — developer portal developer.kroger.com; token endpoint `https://api.kroger.com/v1/connect/oauth2/token`. Client credentials for products/locations; authorization-code flow for cart/profile. Scopes seen in client docs: `product.compact`, `cart.basic:write`, `profile.compact`. Daily limits reported by a community client: products 10,000, locations 1,600, cart 5,000 (verify on portal).
- **api-partner** — reading the cart and fuller data is reported as Partner-API only (community client README, unverified against portal).
- **mcp** — community server CupOfOwls/kroger-mcp (needs the user's own Kroger API credentials); also an npm `@striderlabs/mcp-kroger` (browser-automation style, unverified).

## Data

Products (name, brand, size, price, aisle, UPC) per store location; store lookup; cart write. No order or receipt history in the public API.

## FoodSavr mapping

Enrichment and price lookup (`products`, `prices`) and push of a FoodSavr shopping list into a Kroger cart (`lists` out). Not a source of purchases, so no `LineItem` import. UPC lets products map to barcode-keyed inventory.

## Risks and constraints

Public API terms apply; app registration needed. Purchase history only via private web endpoints or receipt scraping (see existing work), which risks ToS breach.

## Existing work

- https://github.com/CupOfOwls/kroger-api — Python client
- https://github.com/CupOfOwls/kroger-mcp — MCP server
- https://github.com/BLANXLAIT/krocli — CLI
- https://github.com/callaginn/kroger-sweeper — receipt scraper via Kroger.com (puppeteer/playwright)

## Sources

- https://pypi.org/project/kroger-api/ — client, scopes, limits
- https://github.com/CupOfOwls/kroger-mcp — MCP server
- https://ecommerceguide.com/mcp/kroger/ — Public vs Partner API summary
- https://awesome.ecosyste.ms/projects/github.com%2Fcallaginn%2Fkroger-sweeper — receipt scraper
