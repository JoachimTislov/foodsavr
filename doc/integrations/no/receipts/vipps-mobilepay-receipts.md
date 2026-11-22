---
id: no-vipps-receipts
name: Vipps MobilePay receipts (Order Management API)
scope: no
category: receipts
operator: Vipps MobilePay AS
access: [api-partner, none]
auth: oauth2
data: [purchases, line-items, orders]
item_level: true
cost: unknown
user_base: Vipps is Norway's dominant mobile wallet (size unverified)
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Vipps MobilePay receipts

Vipps lets merchants attach digital receipts (order lines with VAT) to a payment; the buyer sees them in the Vipps app order history. The documented API is merchant-side (write). No consumer-side or third-party read API was found, so FoodSavr cannot pull a user's receipts.

## Access

- **api-partner** (merchant-side only) — Order Management API: `POST /order-management/v2/{paymentType}/receipts/{orderId}` (ecom or recurring); Vipps Checkout can generate receipts via `OrderSummary`. Requires being a Vipps merchant. Docs and OpenAPI: developer.vippsmobilepay.com.
- **none** — no documented way for an end-user app to read receipts from the Vipps wallet. Whether the app exposes an export is unverified (searches found nothing).

## Data

Receipt content is merchant-supplied: order lines with VAT. Read side unavailable.

## FoodSavr mapping

Only relevant if FoodSavr itself were a merchant. For user purchases it does not help; Vipps Login/ePayment APIs are out of scope.

## Risks and constraints

Merchant onboarding and Vipps terms apply; a consumer-data read API would require a Vipps partnership (unverified).

## Existing work

None for read access. Vipps publishes an agent toolkit and `llms.txt` for its merchant docs.

## Sources

- https://developer.vippsmobilepay.com/docs/APIs/order-management-api/order-management-api-guide — receipts endpoint
- https://developer.vippsmobilepay.com/docs/APIs/product-mapping/ — API overview
- https://developer.vippsmobilepay.com/llms.txt
