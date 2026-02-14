# Recipes Subcollection

The `recipes` subcollection is nested under each user's document and stores their private recipes. There is also a global `recipes` collection for shared recipes.

## Collection Path

`/users/{userId}/recipes/{recipeId}`

## Structure

```
/recipes/{recipeId}
  - name: "My Private Lasagna"
  - description: "A secret family recipe."
  - createdBy: "{userId}"
```

### Ingredients Subcollection

Each recipe has an `ingredients` subcollection that lists the products needed for the recipe.

#### Collection Path

`/users/{userId}/recipes/{recipeId}/ingredients/{ingredientId}`

#### Structure

```
/ingredients/{ingredientId}
  - productRef: /globalProducts/{productId}
  - quantity: "200g"
```
