---
id: us-heb
name: H-E-B
scope: us
category: grocery-retail
operator: H-E-B
access: [api-private, mcp]
auth: oauth2
data: [products, prices, lists]
item_level: true
cost: free
user_base: Texas and northern Mexico
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# H-E-B

H-E-B has no public API. Several community projects reverse-engineer the My H-E-B app and heb.com and expose them as MCP servers.

## Access

- **api-private** — My H-E-B GraphQL/REST (reverse-engineered by `my-heb-proxy`; iHildy/heb-sdk-unofficial).
- **mcp** — texas-grocery-mcp (PyPI, MIT, product search, cart, coupons; uses web APIs and browser automation); dkaygithub/heb-mcp (single-user, OAuth).
- Paid H-E-B API wrapper on Zyla Labs (commercial, third-party).

## Data

Product search, cart, coupons; order history coverage unverified.

## FoodSavr mapping

Cart/list push and product enrichment; purchases only if order history is exposed (unverified).

## Risks and constraints

Unofficial; H-E-B terms apply; endpoints can change.

## Existing work

- https://pypi.org/project/texas-grocery-mcp/
- https://github.com/iHildy/heb-sdk-unofficial (named in heb-mcp)

## Sources

- https://pypi.org/project/texas-grocery-mcp/ — MCP server
- https://glama.ai/mcp/servers/ge5nke5jq0 — listing
- https://www.zylalabs.com/api-marketplace/other/h-e-b+us+grocery+api/12513 — paid wrapper
