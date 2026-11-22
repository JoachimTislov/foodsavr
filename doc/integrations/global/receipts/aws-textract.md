---
id: global-aws-textract
name: AWS Textract AnalyzeExpense
scope: global
category: receipts
operator: Amazon Web Services
access: [api-public]
auth: api-key
data: [line-items, purchases]
item_level: true
cost: paid
user_base: developer API; user base n/a
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# AWS Textract AnalyzeExpense

AnalyzeExpense extracts summary fields and line-item groups from receipts and invoices.

## Access

- **api-public** — AWS SDK (`AnalyzeExpense`) with IAM credentials; per-page pricing; free tier for new accounts (unverified).

## Data

Returns structured JSON for a receipt image/PDF: merchant, date, totals, tax, and line items (description, quantity, unit price, total). Product codes/EAN are rarely extracted (unverified). Accuracy varies with print quality and language.

## FoodSavr mapping

`purchases` plus `LineItem` from a photo the user takes in-app. Item descriptions are often abbreviated store text and need normalization/matching to products; no expiry.

## Risks and constraints

- AWS account; non-Firebase stack.

## Existing work

- Generic SDKs.

## Sources

- https://docs.aws.amazon.com/textract/latest/dg/invoices-receipts.html — AnalyzeExpense
