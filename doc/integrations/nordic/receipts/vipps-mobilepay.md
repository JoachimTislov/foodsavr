---
id: nordic-vipps-mobilepay
name: Vipps MobilePay
scope: nordic
category: receipts
operator: Vipps MobilePay AS
access: [api-partner]
auth: oauth2
data: [purchases, line-items]
item_level: true
cost: partner
user_base: Nordic mobile wallet (NO, DK, FI); size unverified
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Vipps MobilePay

Nordic mobile wallet from the merged Vipps (NO) and MobilePay (DK/FI). The developer platform is merchant-side: merchants create payments and can attach receipts that show in the user's app. No documented consumer-side API to read a user's receipts or payment history was found. The Norway receipt angle is covered under `no/`.

## Access

- **api-partner** — Merchant APIs only: ePayment (current), eCom (legacy, maintenance mode), Checkout, Order Management, PSP APIs. Receipts endpoint: `POST /order-management/v2/{paymentType}/receipts/{orderId}`, production server only ([Order Management guide](https://developer.vippsmobilepay.com/docs/APIs/order-management-api/order-management-api-guide)). It writes receipts into the app; a third party cannot read them with it.
- No consumer read API or unofficial client found (unverified beyond a docs search). Official SDKs exist ([vippsas/node-sdk](https://github.com/vippsas/node-sdk)); the only MCP server seen is a third-party beta listing on [unified.to](https://unified.to/integrations/mobilepay).

## Data

Merchant-supplied order lines and receipts shown in the app. Not readable by FoodSavr.

## FoodSavr mapping

Useful only if FoodSavr acts as a merchant, or through a bank/receipt partner reading the same transactions. Not an inventory input today.

## Risks and constraints

- Onboarding and content-monitoring duties apply to merchants.
- MobilePay (DK/FI) PSP docs not checked in detail (unverified).

## Existing work

None for reading user receipts.

## Sources

- https://developer.vippsmobilepay.com/docs/APIs/ — API overview
- https://developer.vippsmobilepay.com/docs/APIs/order-management-api/order-management-api-guide — receipts endpoint
- https://developer.vippsmobilepay.com/docs/APIs/ecom-api/vipps-ecom-api — eCom legacy status
