---
id: us-amazon-fresh-whole-foods
name: Amazon Fresh / Whole Foods
scope: us
category: online-grocery
operator: Amazon.com, Inc.
access: [export, bot, mcp]
auth: username-password
data: [orders, line-items, purchases]
item_level: true
cost: free
user_base: Very large US base
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Amazon Fresh / Whole Foods

Amazon has no consumer order API. Fresh and Whole Foods orders sit in the Amazon account; the practical route is the account data export or browser automation.

## Access

- **export** — Amazon 'Request Your Data' yields CSVs including Retail.OrderHistory; takes days up to ~30; per-region accounts. Whether Fresh/Whole Foods grocery lines appear is unverified.
- **bot** — browser extensions (Amazon Order History Exporter) and scripts export order pages to CSV.
- **mcp** — community `amazon-order-history-csv-download-mcp` exports orders/items/shipments across regions (unofficial).

## Data

Order date, item title, ASIN, quantity, price. No EAN; grocery items are free-text-ish titles.

## FoodSavr mapping

Orders to `LineItem` through CSV import; match by title as ASIN has no barcode. Quantities in pack units; no expiry.

## Risks and constraints

Automation breaches Amazon conditions; export is user-driven and compliant. Reliability of grocery lines unknown.

## Existing work

- https://github.com/marcusquinn/amazon-order-history-csv-download-mcp

## Sources

- https://github.com/marcusquinn/amazon-order-history-csv-download-mcp — MCP exporter
- https://takeoutday.org/guides/how-to-download-amazon-data — export guide
- https://tinyapps.org/blog/202303250700_amazon_order_history_reports.html — order history reports
