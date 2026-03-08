# Research: Kassal.app API for Norwegian Groceries

## API Overview
- **Base URL:** https://kassal.app/api/v1
- **Authentication:** Bearer Token (API Key generated from profile settings).
- **Rate Limit:** 60 requests per minute.
- **Hobby Tier:** Free for non-commercial use.

## Primary Endpoints
1. **Search by Barcode (EAN):**
   - `GET /products?search={EAN_NUMBER}`
   - Use `unique=true` to avoid duplicates from different store chains.
2. **Product Details:**
   - `GET /products/{id}`
   - Includes price history and allergens.

## Key Metadata Fields
- `name`: Localized Norwegian name.
- `brand`: Brand name.
- `ean`: 13-digit barcode.
- `image`: URL to product image.
- `current_price`: Latest tracked price.
- `store`: Store information.

## Integration Note for FoodSavr
- This is the highest quality source for Norwegian-specific grocery data.
- Requires registration at kassal.app to get a token.
- Swagger documentation: https://kassal.app/api/v1/docs