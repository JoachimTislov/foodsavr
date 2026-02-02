# Users Collection

The `users` collection stores private information for each user. Each document is identified by the user's unique ID (`userId`).

## Collection Path

`/users/{userId}`

## Structure

```
/users/{userId}
  - email: "user@example.com"
  - name: "John Doe"
  - role: "user" | "admin"
```

## Subcollections

The `users` collection contains several subcollections for managing user-specific data:

*   **Inventory:** [inventory.md](./inventory.md)
*   **Shopping Lists:** [shopping-lists.md](./shopping-lists.md)
*   **Recipes:** [recipes.md](./recipes.md)
*   **Meals:** [meals.md](./meals.md)
*   **Meal Plans:** [meal-plans.md](./meal-plans.md)
