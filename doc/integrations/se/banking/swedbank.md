---
id: se-swedbank
name: Swedbank Open Banking (PSD2)
scope: se
category: banking
operator: Swedbank AB
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: free
user_base: Large Swedish retail bank; also Baltics (exact size unverified)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Swedbank Open Banking (PSD2)

Swedbank offers PSD2 Account Information (AISP) and Payment Initiation (PISP) APIs for Sweden and the Baltics through a developer portal. Gives merchant-level transactions, no line items.

## Access

- **api-public (regulated)** — free for FSA-regulated third parties; needs eIDAS certificates and registration in the developer portal; sandbox available. Documentation sits behind portal login. The accounts/transactions endpoint supports `pageSize` pagination (December 2024 news).
- Indirect access through aggregators (Tink, Enable Banking and similar) is the realistic route for an app without a PSD2 licence; see `eu` scope.

## Data

Accounts, balances and transactions with merchant text and amount. No EAN or items.

## FoodSavr mapping

Merchant-level purchase signal (grocery totals, delivery services) to prompt receipt matching; not inventory.

## Risks and constraints

Direct access requires an AISP/TPP licence or an aggregator contract; consent expiry applies (length unverified).

## Existing work

- https://github.com/robinryden/swedbank-open-banking (Go)
- https://github.com/LeKristapino/swedbank-open-banking-ruby

## Sources

- https://www.swedbank.com/openbanking/faq — AISP/PISP, free, certificates, sandbox
- https://swedbank.com/news.c261b128-a328-42d0-8505-70c3c036df2e.html — pageSize change
- https://www.swedbank.com/openbanking/golive — go-live steps
