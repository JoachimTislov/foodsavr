# Firestore Data Model for foodsavr

This document provides a summary of the Cloud Firestore data model for the foodsavr application. The data is structured in a NoSQL format, with collections and documents, and is designed to be scalable and efficient for common queries.

The collections are listed here in order of their essentiality to the core functionality of the application.

## Core Entities

These are the fundamental building blocks of the application.

*   [Users](./firebase-store/users.md)
*   [Global Products](./firebase-store/global-products.md)

## User-Specific Entities

These collections store data that is specific to each user.

*   [Inventory](./firebase-store/inventory.md)
*   [Shopping Lists](./firebase-store/shopping-lists.md)
*   [Recipes](./firebase-store/recipes.md)
*   [Meals](./firebase-store/meals.md)
*   [Meal Plans](./firebase-store/meal-plans.md)

## Collaborative Entities

This collection handles the social and collaborative features of the application.

*   [Groups](./firebase-store/groups.md)

## Security Rules

Rules guarding access to these collections are detailed here:

- [Firestore Security Rules](./rules.md) document.

