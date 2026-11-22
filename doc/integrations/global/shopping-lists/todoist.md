---
id: global-todoist
name: Todoist
scope: global
category: shopping-lists
operator: Doist
access: [api-public, mcp]
auth: oauth2
data: [lists]
item_level: false
cost: freemium
user_base: tens of millions of users worldwide (vendor claim, unverified)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Todoist

General task manager commonly used for shopping lists via a project. Its documented API makes it a reliable list sync target.

## Access

- **api-public** — REST API and Sync API at developer.todoist.com; OAuth2 app registration or personal token; webhooks. Free tier supported.
- **mcp** — an MCP server for Todoist exists (official status unverified; check Todoist developer docs).

## Data

Projects, tasks (content, description, due, labels, priority, completion), sections. Free text only; no product identity.

## FoodSavr mapping

`lists` two-way (project = shopping list, tasks = items). Quantity must be parsed from text. Completed tasks are an unreliable purchase signal.

## Risks and constraints

- Rate limits apply (details unverified).
- Low ToS risk with the official API.

## Existing work

- Official SDKs (Python, JavaScript); many third-party integrations.

## Sources

- https://developer.todoist.com/ — developer docs
