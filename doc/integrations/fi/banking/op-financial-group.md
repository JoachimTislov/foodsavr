---
id: fi-op-financial-group
name: OP Financial Group (OP Developer)
scope: fi
category: banking
operator: OP Financial Group (OP Osuuskunta)
access: [api-public, api-partner]
auth: oauth2
data: [purchases]
item_level: false
cost: free
user_base: Finland's largest retail bank group (size unverified)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# OP Financial Group

OP runs an open developer portal. PSD2 sandbox is free for licensed and unlicensed developers; production is for licensed TPPs. Transactions only, merchant-level.

## Access

- **api-public** — Sandbox at [op-developer.fi](https://op-developer.fi/) for PSD2 Account Information, Payment Initiation and Confirmation of Funds. Sign up and create an application. Needs mutual TLS and a JWT signing keypair; eIDAS certificates or sandbox certificates from OP's generator; third-party test certs unsupported ([sandbox article](https://op-developer.fi/articles/psd2-sandbox-launched)).
- **api-partner** — Production available to licensed TPPs since Sep 2019 ([production article](https://op-developer.fi/articles/ops-psd2-apis-up-and-running-in-production), [TPP setup](https://op-developer.fi/p/psd2-tpp-setup)). Support: tpp-support@op.fi.
- Aggregators such as Enable Banking cover OP (see `nordic/banking/enable-banking.md`; OP coverage unverified).

## Data

Accounts, balances, transactions (date, amount, counterparty text). No line items.

## FoodSavr mapping

Spend and merchant signals only; "shopped at K/S-store" nudges.

## Risks and constraints

TPP licence or aggregator; SCA renewals; GDPR financial data.

## Existing work

Not researched beyond OP's portal.

## Sources

- https://op-developer.fi/
- https://op-developer.fi/articles/psd2-sandbox-launched
- https://op-developer.fi/p/psd2-tpp-setup
- https://op-developer.fi/articles/ops-psd2-apis-up-and-running-in-production
