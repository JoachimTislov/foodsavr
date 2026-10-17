# Integrations

## Built (absorbed from code @ 103a70f)

- **Rema** — implemented client: `lib/features/third_party_integration/clients/rema_client.dart` over `base_client.dart`.
- **Receipts** — `receipt_recognition` ingestion service (#184).
- **Barcodes** — ML Kit scanning with Open Food Facts enrichment.
- **Expiry** — OCR scanning service.

## Stubbed / researched (code status)

- **Coop** — stubbed client returning empty lists (`coop_client.dart`); replacement tracked in #194.
- **Trumf / Storebox** — researched only, no clients.

## Spec-ahead

- All clients normalized through `foodsavr_core` into LineItem (#192).
- Order systems (e.g. Pizzabakeren) as an input class per the project vision.
- Recipes and free text as input classes.
