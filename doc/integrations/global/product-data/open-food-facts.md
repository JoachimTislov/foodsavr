---
id: global-open-food-facts
name: Open Food Facts
scope: global
category: product-data
operator: Open Food Facts (non-profit association)
access: [api-public, mcp, feed, export]
auth: none
data: [products, nutrition]
item_level: true
cost: free
user_base: Crowdsourced; 3M+ products worldwide (per MCP directory listing), strongest in FR/EU
tos_risk: low
fit: 5
status: researched
last_verified: 2026-11-21
---

# Open Food Facts

Open Food Facts (OFF) is the open, crowd-sourced food product database (barcode, ingredients, allergens, Nutri-Score, NOVA, Eco-Score, images). FoodSavr already uses it for barcode enrichment; this entry records the current API state and MCP options.

## Access

- **api-public (read)** - `https://world.openfoodfacts.org/api/v2/product/{barcode}` and v3 `/api/v3/product/{barcode}`. Docs state v3 (latest 3.6) is recommended for new integrations; v2 is deprecated but supported; structured search exists only in v2. No key for reads; a custom `User-Agent: AppName/Version (contact)` is required.
- Rate limits per IP: product reads 15/min, search 10/min; exceeding can lead to IP bans. Writes are not rate limited. Do not use search for search-as-you-type.
- **api-public (write)** - contribute products/photos with OFF account credentials (session cookie, or `user_id`+`password` on POST); include `app_name`, `app_version`, `app_uuid`. Staging environment available. Keycloak/OIDC bearer tokens are planned.
- **api-public (search)** - full-text search is moving to Search-a-licious (`search.openfoodfacts.org`); legacy `/cgi/search.pl` still works.
- **feed** - daily CSV/JSONL/MongoDB dumps and Parquet on Hugging Face for bulk/offline use (recommended for high volume).
- **mcp** - community servers only, no official one found: JagjeevanAK/OpenFoodFacts-MCP, caleb-conner/open-food-facts-mcp, PayCode-Studio/mcp-open-food-facts, PyPI `openfoodfacts-mcp-server`, npm `openfoodfacts-mcp`; one hosted public endpoint is listed in a directory (unverified, third party).

## Data

Per product: `code` (EAN/UPC), `product_name`, `brands`, `quantity`, `categories_tags`, `ingredients_text`, `allergens_tags`, `nutriments` (per 100 g/ml), `nutriscore_grade`, `nova_group`, `ecoscore_grade`, `image_url`, `packagings`. Coverage and quality vary per product (crowd-sourced). Use the `fields=` parameter to limit payload.

## FoodSavr mapping

Enrichment only: barcode to `LineItem` name, brand, quantity, category, allergens, nutrition. No expiry data. Also usable to write back missing products scanned by users (opt-in).

## Risks and constraints

- ODbL database licence, DbCL contents, CC BY-SA images: attribution and share-alike obligations when redistributing derived data.
- Missing/incorrect entries are common; treat as best-effort.
- IP-based limits: shared egress from a backend can hit limits; prefer client-side lookups or a local dump.

## Existing work

- Official SDKs: openfoodfacts-dart (Flutter), openfoodfacts-python, -js, -java (see GitHub org openfoodfacts).
- Community MCP servers listed above.

## Sources

- https://openfoodfacts.github.io/openfoodfacts-server/api/ - API v2/v3 status, rate limits, User-Agent, auth, ODbL
- https://github.com/openfoodfacts - org with SDKs
- https://pypi.org/project/openfoodfacts-mcp-server - MCP server
- https://mcp.so/server/OpenFoodFacts-MCP/JagjeevanAK - MCP directory entry
- https://glama.ai/mcp/servers/@caleb-conner/open-food-facts-mcp/tree - MCP directory entry
