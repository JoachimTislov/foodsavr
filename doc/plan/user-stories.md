# User stories

This document details the intended user interactions and functional goals for `foodsavr`.
These stories guide the development of the application and help ensure that all features provide clear benefits to the end user.

## Authentication and security

Manage your account and data access securely with these features:

- **Sign up:** As a user, I want to sign up with my email and password or third-party accounts (Google, Facebook, Vipps) to create a profile easily.
- **Login:** As a user, I want to log in with my credentials to access my personal inventory and data.
- **Account management:** As a user, I want to change my password or delete my account to maintain control over my personal information.
- **Security:** As a user, I want to enable two-factor authentication to increase the security of my account.
- **Session control:** As a user, I want to view active sessions and revoke access if I see suspicious activity.

## Inventory management

Track what you have and reduce food waste with effective inventory tools:

- **Inventory overview:** As a user, I want to view my current inventory to know exactly what I have in stock.
- **Expiration reminders:** As a user, I want to receive reminders before products expire to avoid wasting food.
- **Search and filter:** As a user, I want to search and filter my inventory by name, category, or storage location (fridge, freezer, cabinet).
- **Add products:** As a user, I want to add products by scanning barcodes or entering details manually.
- **Stock tracking:** As a user, I want to transfer items from my shopping list to my inventory once I buy them.

## Recipes and meal planning

Plan your meals and manage your cooking efficiently:

- **Recipe management:** As a user, I want to store and categorize my recipes to reuse them later.
- **Scaling:** As a user, I want to adjust serving sizes in recipes to automatically scale the required ingredient amounts.
- **Meal plans:** As a user, I want to create calendar-based meal plans to organize my weekly cooking.
- **Waste reduction:** As a user, I want my meal plan to link with product expiration dates to prioritize using older items.
- **Coordination:** As a group member, I want to view shared meal plans to avoid duplicate cooking with others in my household.

## Shopping lists

Simplify your shopping experience with automated lists:

- **Auto-generation:** As a user, I want my shopping list to be generated automatically from my meal plan to save time.
- **Deduplication:** As a user, I want duplicate items in the shopping list to be merged into a single entry.
- **Fulfillment:** As a user, I want to mark items as bought so that my inventory updates automatically.

## Groups and collaboration

Work together with family or housemates:

- **Group creation:** As a user, I want to create a group and invite others via email to share meal plans and recipes.
- **Ownership:** As a group member, I want to know which products are owned by individuals versus the group.
- **Cloning:** As a group member, I want to clone shared items into my private collection so I can keep them if I leave the group.
- **Invitation management:** As a user, I want to accept or decline group invites to control who I collaborate with.

## Technical and administrative

Maintain system integrity and data quality:

- **Data validation:** As a developer, I want all client submissions to be validated before they are saved to the database.
- **Global list management:** As an admin, I want to remove or edit low-quality entries in the global product list to keep the database accurate.
- **Democratic contribution:** As a developer, I want users to contribute to the global list through a voting process to reduce manual admin work.
