---
id: global-bring-mcp
name: Bring! MCP servers (community)
scope: global
category: ai-agents
operator: Community
access: [mcp, api-private]
auth: username-password
data: [lists]
item_level: true
cost: free
user_base: community projects
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Bring! MCP servers (community)

Community MCP servers over the unofficial Bring! API; they let an assistant read and edit Bring lists. See the Bring! entry.

## Access

- **mcp** — arithmetic-zz/bring-mcp-server (Python, MIT; list/add/remove/complete, batch updates), florianwittkamp/bring-mcp (TypeScript), mekanics/mcp-bring (list allowlist option).

## Data

Lists and items as in Bring!.

## FoodSavr mapping

Same as Bring!; MCP is only useful for agent features.

## Risks and constraints

- Unofficial API; credentials in environment variables.

## Existing work

- As listed.

## Sources

- https://github.com/arithmetic-zz/bring-mcp-server — repo
- https://mcpservers.org/servers/florianwittkamp/bring-mcp — listing
- https://glama.ai/mcp/servers/mekanics/mcp-bring — listing
