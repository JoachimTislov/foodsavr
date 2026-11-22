---
id: global-microsoft-to-do
name: Microsoft To Do
scope: global
category: shopping-lists
operator: Microsoft
access: [api-public]
auth: oauth2
data: [lists]
item_level: false
cost: free
user_base: large (bundled with Microsoft accounts); exact unknown
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Microsoft To Do

Task app with lists, accessible via the Microsoft Graph To Do API. Sync target for users on Microsoft accounts.

## Access

- **api-public** — Microsoft Graph `/me/todo/lists` and `/tasks`; OAuth2 (Microsoft identity platform), `Tasks.ReadWrite`; delta queries and change notifications (unverified detail).

## Data

todoTaskList and todoTask resources (title, body, status, importance, dueDateTime). Free text.

## FoodSavr mapping

`lists` two-way via free-text titles. Quantity parsing needed.

## Risks and constraints

- Requires Azure app registration; personal vs work accounts differ in consent.
- Graph throttling applies.

## Existing work

- Official Graph SDKs; third-party sync tools.

## Sources

- https://learn.microsoft.com/en-us/graph/api/resources/todo-overview — To Do API overview
