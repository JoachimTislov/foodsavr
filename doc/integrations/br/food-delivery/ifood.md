---
id: br-ifood
name: iFood
scope: br
category: food-delivery
operator: iFood (Prosus)
access: [api-partner, mcp]
auth: oauth2
data: [orders]
item_level: false
cost: partner
user_base: Brazil's largest delivery platform
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# iFood

iFood has merchant APIs (orders, menus, status) behind the developer portal; consumer history not exposed. Open Delivery spec used by the sector.

## Access

- **api-partner** — developer.ifood.com.br (not fetched; unverified); Open Delivery spec; SDK openifood.
- **mcp** — community arioliv/ifood-mcp (unverified scope).

## Data

Merchant-side.

## FoodSavr mapping

Not applicable to diners.

## Risks and constraints

Partner access.

## Existing work

- https://openifood.gitbook.io/open-ifood-sdk/
- https://mcpservers.org/pt-BR/servers/arioliv/ifood-mcp

## Sources

- https://openifood.gitbook.io/open-ifood-sdk/ — SDK
- https://api-docs.mykeeta.com/apis/opendelivery — Open Delivery spec
- https://mcpservers.org/pt-BR/servers/arioliv/ifood-mcp — MCP
