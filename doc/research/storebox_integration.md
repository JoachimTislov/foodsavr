# Storebox Receipt Integration Research

**Date:** 2026-05-03
**Status:** Research / Backlog
**Target:** Storebox API (Nets / Nexi Group)
**Context:** FoodSavr "Tempting Integrations" (TODO.md) - Automatic receipt scanning and inventory updates.

---

## Executive Summary

Storebox is the leading digital receipt provider in the Nordic region, widely used by merchants and supported by the Nets / Nexi Group. Integrating Storebox into **FoodSavr** would allow users to automatically sync their grocery purchases directly into their food inventory by reading the line items off their digital receipts.

However, Storebox operates primarily as a B2B (Business-to-Business) service. Their official Receipt Data API (RDA) requires a commercial agreement, API credentials, and backend-to-backend authentication. Unofficial integrations exist but rely on reverse-engineering the consumer web app's authentication.

## Technical Architecture (Storebox API)

Based on official developer portal documentation and community-driven API wrappers, here is the technical structure of the Storebox ecosystem:

### 1. Official Receipt Data API (RDA)
The RDA is designed for trusted third parties (banks, accounting software, and receipt aggregators).
- **Format:** RESTful JSON API.
- **Authentication:** Requires HTTP Basic Auth / Bearer Token provided via a B2B commercial agreement. **Direct client-side (mobile app) calls are discouraged for security.**
- **Key Endpoints:**
  - `GET /receipts`: Fetches a paginated list of receipts (filterable by date, merchant, total).
  - `GET /receipts/{id}`: Fetches the detailed structured JSON of a single receipt.
  - `GET /receipts/{id}/pdf`: Fetches the PDF version of a receipt.
- **Data Structure (The "Holy Grail" for FoodSavr):**
  The response from `GET /receipts/{id}` contains structured line items:
  ```json
  {
    "merchant": {
      "name": "REMA 1000",
      "logoUrl": "..."
    },
    "transaction": {
      "time": "2026-05-03T14:30:00Z",
      "total": 450.50,
      "currency": "NOK"
    },
    "lines": [
      {
        "name": "Milk 1L Q-Meieriene",
        "quantity": 2,
        "price": 22.90
      },
      {
        "name": "Norvegia Cheese 1kg",
        "quantity": 1,
        "price": 119.00
      }
    ]
  }
  ```

### 2. Unofficial / Reverse-Engineered APIs
Since the official API requires a partnership, developers often build wrappers (e.g., the `madsbuch/storebox-api` Node.js wrapper) by interacting with the Storebox consumer web dashboard.
- **Mechanism:** Users authenticate with their Storebox credentials (or via an SSO/BankID flow depending on the region) to acquire an `auth-token` (session cookie).
- **Risk:** This approach is brittle. If Storebox changes their frontend authentication flow or DOM structure, the wrapper breaks. Furthermore, asking users for their Storebox credentials poses significant security and trust issues.

## FoodSavr Integration Strategy

To map Storebox data to the FoodSavr application, the following architecture is recommended:

### Phase 1: The Mock Integration (Current Stage)
Before securing a B2B agreement, we should build the UI and data mapping logic using a mock service.
1.  **Mock Service (`lib/services/mock_storebox_service.dart`)**: Create a service that simulates the RDA, returning fake JSON receipts.
2.  **Mapping Layer (`lib/utils/receipt_parser.dart`)**: Build a parser that converts Storebox `lines` into FoodSavr `Product` and `InventoryItem` models.
    - *Challenge:* Storebox line items are raw strings (e.g., "Milk 1L"). We need an NLP or Fuzzy Matching layer to map these strings to our global product catalog or create new products dynamically.
3.  **UI/UX (`lib/views/receipt_import_view.dart`)**: Build a "Review Import" screen where users can see what was found on the receipt and adjust quantities/expiry dates before confirming the import into their inventory.

### Phase 2: Production Integration
Once a B2B agreement is signed:
1.  **Backend Proxy (Firebase Cloud Functions)**: Implement the official RDA connection in Node.js/TypeScript. The mobile app should *never* hold the Storebox API keys.
2.  **Authentication Flow**:
    - The user links their Storebox account to FoodSavr via an OAuth2/Webflow in the app.
    - Storebox provides a user-specific access token to our Firebase backend.
3.  **Webhook / Polling**:
    - Ideally, Storebox pushes a webhook to our Firebase Function when a new receipt is generated.
    - Alternatively, our backend polls `GET /receipts` daily for new transactions.

## Limitations & Challenges

1.  **B2B Barrier:** We cannot access the official API without contacting `partner@storebox.com` and signing an agreement. This is the biggest immediate blocker.
2.  **Data Quality:** POS (Point of Sale) text is notoriously messy (e.g., "B.M. KANELSNURR 2P"). Mapping these strings to clean `Product` entities with accurate expiry estimates will likely require an LLM or a sophisticated categorization engine.
3.  **User Privacy:** Receipts contain sensitive location and lifestyle data. FoodSavr must update its Privacy Policy and ensure strict data isolation in Firestore (as per the `TODO.md` security goals).

## Actionable Next Steps

1.  **Short Term:** Add a `MockReceiptService` to the Flutter app to design the "Receipt Import" UX without needing real API keys.
2.  **AI Parsing Spike:** Prototype an LLM-based parser (e.g., passing the raw receipt JSON to Gemini) to extract standardized product names and estimate shelf life.
3.  **Business Dev:** Reach out to Storebox/Nets regarding a developer account or sandbox access for a startup/prototype application.
