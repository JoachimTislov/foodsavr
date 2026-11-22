---
id: global-google-wallet
name: Google Wallet passes
scope: global
category: receipts
operator: Google
access: [api-public, export]
auth: none
data: [purchases]
item_level: false
cost: free
user_base: very large
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Google Wallet passes

Wallet passes (loyalty, offers, generic) can carry store loyalty cards; Google Wallet has no API for reading a user's receipts or purchases. Value: store loyalty card numbers a user already holds.

## Access

- **api-public** — Google Wallet API issues passes from an issuer; it does not expose user's existing passes to third parties (unverified).

## Data

Pass fields (barcode, store name, balance, offers). No itemized purchase history.

## FoodSavr mapping

Could issue FoodSavr loyalty-style passes or shopping list passes; cannot import purchases. Possibly useful to import a loyalty card barcode via user scan instead.

## Risks and constraints

- Wallet read access is restricted by platform; issuing passes needs a developer account.

## Existing work

- None relevant.

## Sources

- https://developers.google.com/wallet — Wallet API
