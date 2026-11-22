---
id: global-tasty-api
name: Tasty API (BuzzFeed, via RapidAPI)
scope: global
category: recipes
operator: BuzzFeed Tasty / RapidAPI
access: [api-partner]
auth: api-key
data: [recipes, nutrition]
item_level: true
cost: freemium
user_base: Global; recipe/video catalogue
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Tasty API (BuzzFeed, via RapidAPI)

Unofficial-distribution API for BuzzFeed Tasty recipes (with video) sold through RapidAPI. Not an official BuzzFeed developer programme (unverified).

## Access

- **api-partner** - RapidAPI marketplace listing `tasty.p.rapidapi.com` (`recipes/list`, `recipes/get-more-info`); RapidAPI key; free tier with low monthly quota (verify).

## Data

Recipes with `sections[].components` ingredients, `instructions`, `nutrition`, `video_url`, tags.

## FoodSavr mapping

Recipe discovery; limited value vs Spoonacular.

## Risks and constraints

- Content licensing unclear; RapidAPI listing may change or disappear.

## Existing work

- No MCP server found.

## Sources

- https://rapidapi.com/apidojo/api/tasty - RapidAPI listing
