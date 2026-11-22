---
id: global-mcp-registry
name: Official MCP Registry
scope: global
category: ai-agents
operator: Model Context Protocol project
access: [api-public, feed]
auth: none
data: [products, recipes, lists]
item_level: false
cost: free
user_base: registry for the MCP ecosystem
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Official MCP Registry

Public catalogue of MCP servers. FoodSavr can query it to discover grocery/recipe/food servers, and could publish its own MCP server there.

## Access

- **api-public** — `registry.modelcontextprotocol.io`, read endpoint `GET /v0.1/servers` (REST API frozen at v0.1 on 2024-10-24 per project posts); entries are `server.json` under verified reverse-DNS namespaces. Some sources show a v0 path: check live docs.

## Data

Server metadata: name, description, packages/remotes, version.

## FoodSavr mapping

Not a data source itself; discovery and distribution channel. Aggregators: mcp.so, glama.ai, smithery, mcpservers.org.

## Risks and constraints

- Preview-stage registry; vetting is minimal: treat listed servers as untrusted code.

## Existing work

- Many community registries mirror it.

## Sources

- https://modelcontextprotocol.io/registry/about — registry docs
- https://blog.modelcontextprotocol.io/posts/2025-09-08-mcp-registry-preview/ — preview announcement
