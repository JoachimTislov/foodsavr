---
id: global-spoonacular
name: Spoonacular
scope: global
category: recipes
operator: Spoonacular API (Bear Mountain / spoonacular.com)
access: [api-public, mcp]
auth: api-key
data: [recipes, nutrition, products, plans]
item_level: true
cost: freemium
user_base: Widely used food API; global, English-centric
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Spoonacular

Food API covering recipe search by ingredients/diet, ingredient substitutes, nutrition, product search by UPC, meal planning and shopping list endpoints. Useful for 'cook from what I have' queries.

## Access

- **api-public** - `https://api.spoonacular.com/` with `apiKey`; free plan limited (about 150 points/day per a directory listing - verify), paid tiers above; attribution required on free plan.
- Endpoints: `recipes/findByIngredients`, `recipes/complexSearch`, `recipes/{id}/information`, `food/products/upc/{upc}`, `mealplanner/*`, `food/ingredients/substitutes`.
- **mcp** - a Spoonacular MCP server by ddsky is listed in a directory (unverified details).

## Data

Recipes with extendedIngredients (name, amount, unit, aisle), instructions, nutrition, dietary flags; products by UPC with nutrition and badges.

## FoodSavr mapping

Recipes input class: suggest recipes from inventory, import into meal plan, map extendedIngredients to FoodSavr items. UPC endpoint is extra enrichment.

## Risks and constraints

- Points-based quotas; caching of recipe data restricted by ToS (unverified).
- Ingredient names are English; Norwegian matching needs translation.

## Existing work

- Official docs with client examples; community MCP above.

## Sources

- https://spoonacular.com/food-api/docs - API docs
- https://spoonacular.com/food-api/pricing - plans
