---
id: global-azure-document-intelligence
name: Azure AI Document Intelligence (prebuilt receipt)
scope: global
category: receipts
operator: Microsoft
access: [api-public]
auth: api-key
data: [line-items, purchases]
item_level: true
cost: freemium
user_base: developer API; user base n/a
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Azure AI Document Intelligence (prebuilt receipt)

Prebuilt receipt model returning merchant, items, totals.

## Access

- **api-public** — REST API with key or Entra ID; free tier limited pages per month (unverified).

## Data

Returns structured JSON for a receipt image/PDF: merchant, date, totals, tax, and line items (description, quantity, unit price, total). Product codes/EAN are rarely extracted (unverified). Accuracy varies with print quality and language.

## FoodSavr mapping

`purchases` plus `LineItem` from a photo the user takes in-app. Item descriptions are often abbreviated store text and need normalization/matching to products; no expiry.

## Risks and constraints

- Azure subscription needed.

## Existing work

- Generic SDKs.

## Sources

- https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/prebuilt/receipt — receipt model
