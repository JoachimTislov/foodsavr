# Tradesolution MyBrand EPD API research

**Last refreshed:** November 22, 2026
**Status:** Research / B2B candidate
**Target:** Tradesolution MyBrand EPD (*Elektronisk Produktdatabase*)
**Scope:** Authoritative Norwegian grocery product master data (GTIN enrichment)

## Overview

Tradesolution's **MyBrand EPD** is the central product master data database for
the Norwegian grocery, convenience (KBS), and foodservice sectors. Suppliers
and wholesalers use EPD to exchange quality-assured product data keyed by
standard GS1 barcodes (GTINs). For FoodSavr, EPD represents the highest-accuracy
Norwegian product registry for nutrition, ingredients, allergens, and packaging
metadata, though it requires a commercial B2B agreement.

## API versions and endpoints

Tradesolution exposes REST APIs documented with OpenAPI 3.0 / Swagger UI:

- **MyBrand EPD API v2 (recommended):**
  - Base URL: `https://epdapi.tradesolution.no/v2`
  - OpenAPI spec: `https://epdapi.tradesolution.no/v2/swagger/v2/swagger.json`
  - Resource groups include `Product`, `Gtin`, `Packaging`, `Unit`,
    `UnitLevel`, `Variant`, `Brand`, `Classification`, `Content`, `Search`,
    `Export`, `Listing`, `Supplier`, `Receiver`, and `Validation`.
- **MyBrand EPD API v1 (legacy):**
  - Base URL: `https://epdapi.tradesolution.no`
  - Swagger UI: `https://epdapi.tradesolution.no/swagger`
  - OpenAPI spec: `https://epdapi.tradesolution.no/swagger/v1/swagger.json`
  - Tradesolution recommends integrating against **v2** for new integrations.

## Data model and identifiers

Products in EPD follow GS1 and Norwegian grocery industry standards (EPD
Standard 11):

- **GTIN:** Identifies each packaging level (consumer unit / *F-pak*, retail
  carton / *D-pak*, and pallet / *Toppakning*).
- **EPD number (`EPDnr`):** Tradesolution's internal product identifier.
- **GLN:** Identifies the supplier or brand owner.
- **Attributes:** Structured ingredient declarations, nutrition tables,
  allergens, weights and dimensions, deposit (*pant*) metadata, and product
  classifications.

## Authentication and access

Tradesolution secures its APIs with **OAuth 2.0** (`client_credentials` grant),
documented in the public `Tradesolution/Authentication` GitHub repository:

- **Credential provisioning:** Request system-to-system `client_id` and
  `client_secret` credentials via `post@tradesolution.no` (API credentials) or
  `epd@tradesolution.no` (EPD support).
- **Token request (`application/x-www-form-urlencoded`):**
  ```text
  client_id=<client_id>
  &client_secret=<client_secret>
  &grant_type=client_credentials
  &scope=https://trades.no/TradesolutionApi/.default
  ```
- **Token lifetime:** Access tokens expire after 10 hours (`expires_in: 36000`)
  and are sent via `Authorization: Bearer <access_token>`.

Because credentials are system-level B2B secrets, any EPD integration must run
through a backend proxy (such as Cloud Functions or the planned Go/MCP server)
rather than directly from the Flutter client.

## Companion Tradesolution APIs

The same OAuth 2.0 scheme covers related Tradesolution services:

- **MyBrand MediaStore (`https://mediastore.tradesolution.no`):** Product
  images linked directly to EPD GTINs.
- **VetDuAt API:** Product declarations, allergen details, and medium-sized
  product images (`/api/products/usersearch`,
  `/api/images/medium/{gtin}/{gln}/png`).
- **Kjederegisteret API:** Norwegian retail chain structures and store unit
  registers.

## Comparison with other barcode sources

| Source | Scope | Data richness | Access model |
| :--- | :--- | :--- | :--- |
| **Open Food Facts** (currently built) | Global (crowdsourced) | Moderate; uneven Norwegian coverage | Free, open API v3 |
| **Kassal.app** | Norway grocery retail | High (names, brands, prices, images, allergens) | Free hobby tier; commercial agreement for production |
| **GS1 Norway (Verified by GS1)** | Global authoritative registry | Basic identity (GTIN, brand owner, GPC category) | Paid / partner API |
| **Tradesolution EPD** | Norway grocery master data | Comprehensive QA-verified nutrition, allergens, packaging | B2B contract required |

## Next steps for FoodSavr

1. Keep Open Food Facts as the default zero-friction barcode enrichment source.
2. Evaluate Kassal.app or VetDuAt as lighter-weight Norwegian enrichment layers
   before committing to a full EPD B2B contract.
3. If FoodSavr moves toward commercial launch in Norway, contact Tradesolution
   about licensing EPD API v2 + MediaStore behind a server-side lookup cache.
