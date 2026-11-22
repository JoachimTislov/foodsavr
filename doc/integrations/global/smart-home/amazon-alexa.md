---
id: global-amazon-alexa
name: Amazon Alexa
scope: global
category: smart-home
operator: Amazon
access: [none, export]
auth: oauth2
data: [lists]
item_level: false
cost: free
user_base: hundreds of millions of Alexa devices (vendor claim, unverified)
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Amazon Alexa

Voice assistant with Shopping and To-Do lists. Amazon deprecated the List Skill API and List Management REST API on 2024-07-01, so third-party apps can no longer read or write Alexa lists.

## Access

- **none** — List Skill API and List Management REST API are deprecated since 2024-07-01; no replacement list API found.
- **export** — a custom FoodSavr Alexa skill can still receive voice requests ("ask FoodSavr to add milk"), which is the workaround AnyList recommends for its own skill.

## Data

Previously: list items (text) and list events. Now: only intents delivered to a custom skill.

## FoodSavr mapping

A custom skill could push voice-added items into FoodSavr `lists`. Reading existing Alexa lists is not possible.

## Risks and constraints

- Do not plan on list sync. Skill certification and Alexa account linking are required (unverified effort).

## Existing work

- AnyList, others dropped native Alexa sync in July 2024.

## Sources

- https://developer.amazon.com/en-US/docs/alexa/ask-overviews/deprecated-features.html — deprecation notice
- https://help.anylist.com/articles/alexa-skill-update-july-2024/ — impact on AnyList
