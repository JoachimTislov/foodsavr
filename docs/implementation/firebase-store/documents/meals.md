# Meals Subcollection

The `meals` subcollection is nested under each user's document and stores their private meals. There is also a global `meals` collection for shared meals.

## Collection Path

`/users/{userId}/meals/{mealId}`

## Structure

```
/meals/{mealId}
  - name: "My Favorite Breakfast"
  - description: "A quick and easy meal."
```

### Recipes Subcollection

Each meal has a `recipes` subcollection that lists the recipes included in the meal.

#### Collection Path

`/users/{userId}/meals/{mealId}/recipes/{recipeId}`

#### Structure

```
/recipes/{recipeId}
  - recipeRef: /users/{userId}/recipes/{recipeId}
```
