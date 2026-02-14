# Meal Plans Subcollection

The `mealPlans` subcollection is nested under each user's document and manages their meal plans.

## Collection Path

`/users/{userId}/mealPlans/{planId}`

## Structure

```
/mealPlans/{planId}
  - name: "This week's plan"
  - startDate: Timestamp
  - endDate: Timestamp
```

### Entries Subcollection

Each meal plan has an `entries` subcollection that contains the meals scheduled for each day.

#### Collection Path

`/users/{userId}/mealPlans/{planId}/entries/{entryId}`

#### Structure

```
/entries/{entryId}
  - date: Timestamp
  - mealName: "Spaghetti Bolognese" // Denormalized for easy display
  - mealRef: /users/{userId}/meals/{mealId}
```
