---
id: global-google-document-ai
name: Google Document AI Expense Parser
scope: global
category: receipts
operator: Google Cloud
access: [api-public]
auth: api-key
data: [line-items, purchases]
item_level: true
cost: paid
user_base: developer API; user base n/a
tos_risk: low
fit: 5
status: researched
last_verified: 2026-11-21
---

# Google Document AI Expense Parser

Cloud processor for receipts/invoices with line-item entities.

## Access

- **api-public** — Document AI REST/gRPC with Google Cloud service account; Expense Parser processor; per-page pricing; EU/US regions.

## Data

Returns structured JSON for a receipt image/PDF: merchant, date, totals, tax, and line items (description, quantity, unit price, total). Product codes/EAN are rarely extracted (unverified). Accuracy varies with print quality and language.

## FoodSavr mapping

`purchases` plus `LineItem` from a photo the user takes in-app. Item descriptions are often abbreviated store text and need normalization/matching to products; no expiry.

## Risks and constraints

- Requires GCP project/billing; Firebase-adjacent so convenient.

## Existing work

- Generic SDKs.

## Sources

- https://cloud.google.com/document-ai/docs/processors-list — processor list (Expense Parser)
