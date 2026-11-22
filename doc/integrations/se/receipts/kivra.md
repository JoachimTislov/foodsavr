---
id: se-kivra
name: Kivra (digital mail and receipts)
scope: se
category: receipts
operator: Kivra AB
access: [export, api-private, api-partner]
auth: bankid
data: [purchases, line-items]
item_level: true
cost: free
user_base: Swedish digital mailbox with millions of users (exact figure unverified); ICA and others send receipts here
tos_risk: medium
fit: 5
status: researched
last_verified: 2026-11-21
---

# Kivra (digital mail and receipts)

Kivra is Sweden's digital mailbox. Stores send digital receipts to the Kivra account of identified customers (for example ICA Stammis members, Jula, Kjell, Biltema). It is the most promising Swedish source of item-level purchase data.

## Access

- **api-partner (sending only)** — Kivra's developer docs offer Tenant API, Receipt API ("for sending receipts") and Legal API. No consumer or third-party read API was found. Partners sign agreements; API content validation is enforced from 2027-04-30.
- **api-private** — community tools log in with BankID (QR) and download receipts and letters: `felixandersen/kivra-sync` (saves to disk or Paperless-ngx) and `stefangorling/fetch-kivra`. Matmetrics' `kvitto-ica` uses Kivra OAuth2/PKCE for ICA receipts.
- **export** — manual download of receipts in the Kivra app/web.

## Data

Receipts as documents (PDF/HTML). ICA receipts are parsed with line items by matmetrics (field list unverified). A sender-side receipt specification is published at kivra.se (content not reviewed).

## FoodSavr mapping

Purchases with line items, store and date. Quantity and EAN presence per line is unverified; many receipts probably carry names and prices without EAN. Manual import (share/forward PDF) is the lowest-risk first step.

## Risks and constraints

- BankID login must be user-driven; automating it holds user sessions and is not officially sanctioned.
- Receipts are personal data; GDPR consent and minimisation needed.
- Kivra may change its login flow; no read API contract.

## Existing work

- https://github.com/felixandersen/kivra-sync
- https://github.com/stefangorling/fetch-kivra
- https://github.com/khessman/matmetrics
- https://github.com/kivra/kivra-api-errors (sender API errors)

## Sources

- https://kivra.se/sv/foretag/for-utvecklare/introduktion — Tenant, Receipt, Legal APIs
- https://kivra.se/en/business/receipts/receipt-specifications — receipt spec
- https://www.kivra.se/en/business/partnersite/current — API validation 2027-04-30
- https://github.com/felixandersen/kivra-sync — BankID QR download tool
- https://icagruppen.se/arkiv/pressmeddelandearkiv/2019/ica-infor-digitala-kvitton-tillsammans-med-kivra — ICA receipts
