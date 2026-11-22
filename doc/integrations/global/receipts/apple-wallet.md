---
id: global-apple-wallet
name: Apple Wallet passes
scope: global
category: receipts
operator: Apple
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

# Apple Wallet passes

PassKit passes for loyalty/coupons/tickets. Apps can add passes but cannot read others' passes; no purchase data.

## Access

- **api-public** — PassKit (`PKPass`), pass signing certificate required; read access limited to passes issued by the same team (unverified).

## Data

Pass fields (barcode, store name, balance, offers). No itemized purchase history.

## FoodSavr mapping

Could issue FoodSavr loyalty-style passes or shopping list passes; cannot import purchases. Possibly useful to import a loyalty card barcode via user scan instead.

## Risks and constraints

- Wallet read access is restricted by platform; issuing passes needs a developer account.

## Existing work

- None relevant.

## Sources

- https://developer.apple.com/documentation/passkit — PassKit
