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

## Preferences

Per-account behavior preferences live in a settings document, separate from the profile fields above:

`/users/{userId}/settings/preferences`

```
  - expiringSoonDays: 6        (1-30; products expiring within this window are "expiring soon")
  - defaultInventoryId: null   (inventory for new products; null means the first inventory)
```

Missing keys fall back to defaults; clients write with merge so unknown keys survive.
