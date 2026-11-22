---
id: dk-danish-psd2-banks
name: Danish bank PSD2 portals (Danske Bank, Jyske, Nykredit, Sydbank)
scope: dk
category: banking
operator: Danske Bank, Jyske Bank/Sydbank (Bankdata), Nykredit/Arbejdernes Landsbank (BEC)
access: [api-partner]
auth: oauth2
data: [purchases]
item_level: false
cost: unknown
user_base: Nearly all Danish consumers; MitID is the SCA method
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Danish bank PSD2 portals

Danish banks expose PSD2 account-information APIs. Merchant-level data only: shows grocery spend by store, not items. Nordea is covered in `nordic/banking/nordea.md`; aggregators in `nordic/banking/enable-banking.md`.

## Access

- **api-partner** — Danske Bank documents PSD2 APIs for Denmark; production requires a QWAC and QSEAL from a QTSP and PSD2 TPP authorisation ([Danske regulatory APIs](https://developers.danskebank.com/regulatory-apis)). Danish production access is restricted to authorised TPPs per a Danish portal snippet (BEC portal: [apiportal00041.prod.bec.dk](https://apiportal00041.prod.bec.dk/openbanking/sandbox/node/36)). Jyske and Sydbank run on Bankdata; Nykredit, Spar Nord and Arbejdernes Landsbank on BEC ([Enable Banking DK](https://enablebanking.com/docs/markets/dk/)). Sandboxes: Nordea, Saxo, VestjyskBank via Enable Banking; others per bank portal (unverified).
- Via an aggregator (Enable Banking lists Danske, Nordea, Jyske, Sydbank, Nykredit, Spar Nord, Arbejdernes Landsbank) — simpler than per-bank onboarding ([Enable Banking DK](https://enablebanking.com/docs/markets/dk/)).
- Auth: redirect OAuth 2.0; MitID SCA (app-to-app redirect for Danske and Nykredit group).

## Data

Accounts, balances, transactions with counterparty text. History limits not documented on the sources read.

## FoodSavr mapping

Grocery-merchant transactions as "purchase happened" nudges and spend stats. No inventory.

## Risks and constraints

TPP licence or aggregator contract; SCA re-consent; GDPR financial data; bank-specific quirks.

## Existing work

Aggregators (Enable Banking, Tink, GoCardless). No FoodSavr-relevant open-source clients found.

## Sources

- https://developers.danskebank.com/regulatory-apis
- https://enablebanking.com/docs/markets/dk/
- https://openbankingtracker.com/country/dk
- https://apiportal00041.prod.bec.dk/openbanking/sandbox/node/36
