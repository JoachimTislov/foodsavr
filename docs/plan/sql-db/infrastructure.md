# Infrastructure Scalability: Transitioning to SQL

This document outlines the strategic rationale for migrating from Firebase to a SQL-based backend (such as Supabase or PostgREST) as `foodsavr` scales beyond its initial prototyping phase.

## Current State: Firebase for Prototyping

Currently, `foodsavr` leverages Firebase for rapid development and prototyping. Firebase provides:
- **Speed of Implementation:** Out-of-the-box authentication, real-time database, and hosting.
- **Minimal Configuration:** No need to manage server infrastructure or complex schema migrations initially.
- **Generous Free Tier:** Ideal for the early stages of a hobby or startup project.

## The Case for SQL (Supabase / PostgREST)

As the application grows in complexity, particularly with the intricate relationships defined in our [Domain Architecture](relations.md), a relational database becomes essential for long-term scalability and maintainability.

### 1. Complex Relationships and Data Integrity
Our domain model (Users, Groups, Products, Inventory, Recipes, Meals, Shopping Lists) is inherently relational. 
- **ACID Compliance:** SQL databases ensure transactional integrity, which is critical when updating inventory levels across multiple groups or processing shopping list fulfillments.
- **Foreign Key Constraints:** Ensures that a `ShoppingListProduct` cannot exist without a valid `Product`, preventing orphaned data that often plagues NoSQL collections.

### 2. Powerful Querying and Analytics
- **Joins vs. Denormalization:** In Firebase, complex queries often require either massive data denormalization or multiple client-side fetches. SQL allows for efficient server-side joins, reducing bandwidth and improving performance.
- **Aggregation:** Calculating group-wide statistics, predictive budgeting, or nutrient tracking across thousands of entries is significantly more efficient using SQL's native aggregation functions.

### 3. Advanced Filtering with PostgREST
Utilizing **PostgREST** or **Supabase** (which uses PostgREST) provides a RESTful API directly over the PostgreSQL schema.
- **Declarative Filtering:** Simplifies the implementation of the complex filtering logic required for shared group data.
- **Horizontal Scaling:** PostgreSQL is battle-tested for high-concurrency environments, making it easier to scale the compute and storage layers independently.

### 4. Migration Strategy
1. **Schema Mapping:** Translate existing Firestore collections into normalized PostgreSQL tables.
2. **Hybrid Phase:** Gradually move complex reporting and relational features to Supabase while keeping real-time sync in Firebase if necessary.
3. **Full Transition:** Migrate authentication and core storage to the SQL backend once the relational overhead in NoSQL becomes a bottleneck for development speed or performance.

## Conclusion
While Firebase is excellent for getting `foodsavr` off the ground, a SQL-based infrastructure is the recommended path for a robust, scalable, and data-consistent production environment.
