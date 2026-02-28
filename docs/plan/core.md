# Core plan

This document outlines the foundational strategy and goals for `foodsavr`.
It establishes the core principles and intended functionality that drive the development of a seamless, automated food management experience.

## Guiding principles

Develop `foodsavr` with a focus on simplicity and scalability. Adhere to these principles:

- **Outsource when possible:** Leverage external services (like Firebase) to minimize maintenance overhead.
- **Flexible architecture:** Design the system to accommodate future enhancements and changes.
- **Gradual implementation:** Prioritize core features and introduce complex functionalities iteratively.

## Product goals

The application aims to provide a seamless experience where you can manage 
products and meals effortlessly. The system handles the heavy lifting, such as 
tracking inventory and generating shopping lists.

### Automated functionality

- **Inventory tracking:**
    - Automatically sync inventory as you consume meals or buy products.
    - Add products by scanning QR or barcodes.
    - Track quantities and expiration dates.
    - Receive notifications for expiring products.
    - Retrieve detailed product information from global databases.
- **Shopping list generation:** Automatically create lists based on missing inventory or planned meals.
- **External integration:** Import products and recipes from websites and other applications.
- **Global database access:** Add meals, recipes, and products from a curated global database.
- **Discount retrieval:** Get store offers based on your inventory and shopping lists.

### Manual actions

- Create and manage groups or family accounts.
- Set up and update your user profile.
- Register initial inventory through barcode scanning or manual input.
- Add and manage custom meals and recipes.
- Link products to specific meals and recipes.

## Development challenges

Building a seamless and intuitive food management app involves several technical hurdles:

- **Seamless user experience:** Minimizing manual data entry is critical
  Automating as many interactions as possible prevents user fatigue
- **Up-to-date data:** Maintaining accurate product information, prices, and 
  discounts requires robust integration with external APIs or web crawlers.
- **Store integration:** Automatically synchronizing inventory after shopping 
  trips depends on reliable methods for collecting data from various retailers.

## Technical architecture

`foodsavr` is built using a modern, scalable stack and follows a 4-tier 

### Tech stack

- **Frontend:** Flutter (Dart) for cross-platform mobile and web support.
- **Backend:** Firebase services for authentication, serverless compute, and data storage.
- **Database:** Cloud Firestore (NoSQL) for flexible, real-time data management.
- **Dependency injection:** `GetIt` and `injectable` for clean, testable logic.
- **Localization:** `easy_localization` for multi-language support.

### Layered architecture

The project follows a strict separation of concerns through these layers:

1.  **UI (views/ and widgets/):** Handles screen rendering and user interaction. Inject services via `getIt<Service>()`.
2.  **Service (services/):** Orchestrates business logic and validation. Depends on repository interfaces.
3.  **Data (interfaces/ and repositories/):** Manages data persistence and retrieval through defined contracts.
4.  **Domain (models/):** Contains plain data classes with serialization logic and computed properties.

## Database structure

The application uses Cloud Firestore for its primary data storage, [view security rules and structure definitions](../implementation/firebase-store/)

### Core entities

- **Users:** Store user profiles, roles, and preferences.
- **Groups:** Manage collective data sharing among families or housemates.
- **Products:** Define product attributes, categories, and locations.
- **Inventory:** Track current stock, quantities, and expiration dates.
- **Recipes:** Manage ingredient lists and cooking instructions.
- **Meals:** Group recipes into scheduled or reusable meal entries.
- **Shopping lists:** Store items to be purchased, linked to inventory or meal plans.

## Role-based access

Access control is managed through roles defined in user documents:

- **User:** Can manage their own data and group-shared content.
- **Admin:** Can manage global product lists and perform administrative cleanup.
- **SuperAdmin:** Has full access to system-wide settings and administrative oversight.
