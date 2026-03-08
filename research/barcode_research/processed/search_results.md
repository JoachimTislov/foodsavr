==================== BEGIN FETCHED DATA ====================
Web search results for "GS1 Norwegian grocery barcode lookup services":

For looking up Norwegian grocery barcodes (GTINs), there are two primary professional services that provide verified data: GS1 Norway and Tradesolution (EPD).

1. GS1 Norway: "Verified by GS1" API
GS1 Norway offers direct API access to their global registry. This is the most authoritative source for verifying barcode ownership and basic product identity.
- Service Levels: API Basic (GLN, GTIN) and API Pro (includes GLN Notification).
- Data Provided: Product name, brand, category (GPC), company.
- Best For: Barcode validity and brand owner identification.
- Contact: gs1.no (https://gs1.no/tjenester/verified-by-gs1-api/)

2. Tradesolution: EPD API
The EPD (Elektronisk Produkt-Databas) is the industry-standard master data hub for the Norwegian grocery, convenience, and food service sectors. It is managed by Tradesolution.
- Capabilities: Rich metadata (ingredients, nutrition, allergens, dimensions, packaging).
- API Access: REST API with Swagger documentation.
- Quality Assurance: Verified data via mandatory QA process.
- Best For: Apps requiring detailed nutritional/allergen info for the Norwegian market.
- Documentation: http://epdapi.tradesolution.no/swagger/

3. Comparison Summary
GS1 Norway: Identity & Ownership focus, Global scope, Limited nutritional data.
Tradesolution (EPD): Detailed Product Master Data focus, Norway-specific scope, Comprehensive nutritional data.

Implementation Note for FoodSavr:
- Tradesolution (EPD) is the "gold standard" for nutritional/allergen data in Norway.
- GS1 Norway is for verification/brand owner lookup.
- Open Food Facts is a crowdsourced alternative.

==================== END FETCHED DATA ====================