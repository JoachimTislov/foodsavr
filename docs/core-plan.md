# Core functionality implementation plan

There are countless features to include in the application, but these are worthless without the core functionality.

Opt for an event based domain driven design, using generic repository in each domain. One table in the database equals one domain

## Thoughts

- Two factor authentication, and open up for passwordless signins?
    - This might be overkill for a food app ...
- Setup a internal notification system, or just use email?
- Let the user manage all the login sessions
- Should the products contain ingredients?
    - Per 100g ...
    - I think this feature can be added easily later ...
    - This is meant for tracking macros and thats not the main purpose of this application
- If users are in a group will there only be once instance of the product/recipe/meal in the database?
    - .. meaning that multiple people have a relation to the entity it can cause state issues.
    - Use a copy-on-share model
    - Products/meals/recipes and users have many-to-many relationship
    - Users should have their own copy of the original entity to prevent conflicts
        - The copy should take place on "add" for both the group and global list entries
- The inventory needs to shared amoungst the whole group
    - should be asked if they want to share inventory or synchronize them
- Supporting group owned entities is a bad design choice - will cause complex logic when merging and splitting groups
- Add shared flag for visibility group/global
- Allow soft-deletion but not hard-deletion if entities are referenced by others.
    - Deleting a product which is referenced in a meal etc ...
- Create on add new product (this might be mentioned somewhere else)

## Questions

- How should users join each other?
    - Create invite link?
    - The invite can be sent to their mail - easiest solution, I think
    - Resulting in
        - CreateGroup
        - LeaveGroup
        - DeleteGroup
        - Remove user
        - InviteUser
        - AcceptOrDeclineRequest
    - Creating an internal notification system is too much and I think that is the only alternative
        - Can possible migrate to this solution if a notification system is implemented

## TODO research

- DTOs (Data transfer objects)
- JWT
- OAuth
- CORS
- Testing
- AI agent protocol - Web API protocol for autonomous agents
- MCP - model context protocol
- Robot.txt
- Logging for debugging and safety


## Database

Use Spring JPA (Java Persistence API)
Type: PostgreSQL

### Entities

[View relations for more details](./relations.md)

- Users
- Groups
- Products
- Location
- Inventory
- Recipes
- Meals

## API design

I want to use gRPC for type-safety and other reasons
- [grpc-web](https://github.com/grpc/grpc-web)
    - https://www.youtube.com/watch?v=nBOmalmldx8
- [Spring-docs-grpc](https://docs.spring.io/spring-grpc/reference/server.html)
- Client side pkgs
    - grpc-web
    - google-protobuf
    - @types/google-protobuf
- Should keep it modular and not merge all the backend services to one big one, pointless step.
- REST API and gRPC can coexist
    - Debate on implementig both

For server-side clients (Microservices) - https://github.com/grpc-ecosystem/grpc-spring

BUT, I think setting up a REST API is simpler and less complex

## Layers

- Database
    - Should have strict/redundant validation to act as a safety net
- Generic repository
- Domains/Contexts
    - repository
    - service
- API (gRPC) and business logic
- UI/Client

## Roles

User, Admin, SuperAdmin

## Domains

[View relations](./relations.md)

## Food Tracking

- Track products in fridge, freezer, and cabinets (or just a unified inventory if you want simplicity).
- Info: name, price, quantity, expiration date, nutrients (optional).
- Track what has been used and what is left.
    - Delete or archive consumed products?

## Shopping List

- Automatically generate shopping lists from meal plans or missing items.
- Option to mark items as bought and update inventory.
- Reduce duplicate purchases by knowing what’s already in stock.

## Recipes

- Store and manage recipes.
- Automatically check which ingredients are missing and add them to the shopping list.
- Avoid the user having to select each product manually.

## Meal plans

- Consists of recipes
- Follows calender or to keep simple weekly plan
- Should be following the calender to synchronize with the expiration dates

## Products Database

- Maintain a global and personal product list.
- Use barcodes or manual input for easy tracking.
- Optional integration with discounts or store offers.

## Budget and Expense Tracking

- Track shopping costs per trip.
- Cost per meal and product
- Summarize spending over time.

## Steps

[View relations for detailed database design](./relations.md)

1. Configure gRPC and setup the PostgreSQL database
2. Add Logging
3. Setup simple authentication (email and password)
    - Create User table
        - email
        - password
        - login attempts
        - store login state? Im not sure if this would work well; force the client to send a request to the server to logout
    - Setup the initial database logic/layer
    - Make the generic repository with the BaseEntity
    - Create the user and admin domain with CRUD queries
    - Configure the API endpoints for login in and GET users
    - Connect the database layer to the API
    - Create login page and admin manage users - should an admin be allowed to delete users?
4. Setup the basic profile (delete me and update/change password) and create landing page
    - Debate on adding profile picture or anything else
5. Product domain
    - Create global and users product table
        global
        - name
        - type (cabinet, frigde, freezer)
        - Add a mapping table to track which meals its typically used in?
        users (is the same with a userID as foreign key)
        For later
            - ingredients
            - nutrients
6. Shoppinglist domain
7. Ensure the correct access control, validation and functionality
    - Resolve bugs, issues, etc
    - Attempt to determine flaws in the architecture to avoid technical debt in the future
    - FIX all issues harming the implementation of future features.
    - Important to do this at this stage

