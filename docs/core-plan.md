# Core functionality implementation plan

There are countless features to include in the application, but these are worthless without the core functionality.

Opt for an event based domain driven design, using generic repository in each domain. One table in the database equals one domain

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

## API design

I want to use gRPC for type-safety and other reasons
- [grpc-web](https://github.com/grpc/grpc-web)
    - https://www.youtube.com/watch?v=nBOmalmldx8
- [Spring-docs-grpc](https://docs.spring.io/spring-grpc/reference/server.html)

For server-side clients (Microservices) - https://github.com/grpc-ecosystem/grpc-spring

BUT, I think setting up a REST API is simpler and less complex

## Layers

- Database
    - Should have strict/redundant validation to act as a safety net
- Generic repository
- Domains/Contexts
    - repository
    - service
- API and business logic
- UI

## Roles

User, Admin, SuperAdmin (Maybe add GroupMember later if theres actions specific to group members and leader)

## Domains

- admin
- user and/or group
    - Have to figure out the best way to relate users with the same meals.
    without making the logic annoying to deal in many areas
    - Either a group or a user can have a relation to the meal and/or product
    - A group share everything
    - The state is peserved when leaving and joining groups because the users determine the total content of the group
        - Users can be annoyed if a group member leaves and they loose certain meals so this state should be explicit in the UI
        - A user should be allowed to add anothers users meal or product to their favs (private)
    - A user can be in a group and the group ID is used to get the users and IDs in the group to get all the information
    - The group is only intended to be a brigde for people to share their meals and mealplan
    - Giving multiple users access to the same data makes the handling of it complex - Can handled by blocking double updates
        - A simple error informing the user that the current product or meal has already been updated should resolve this
- product: is global and per user
    - Global and private
    - User can decide if they want to contribute to the global repository
- shoppinglist
- recipes
- mealplan
- budget

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

1. Setup simple authentication (email and password)
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
2. Setup the basic profile (delete me and update/change password) and create landing page
    - Debate on adding profile picture or anything else
3. Product domain
    - Create global and users product table
        global
        - name
        - type (cabinet, frigde, freezer)
        - Add a mapping table to track which meals its typically used in?
        users (is the same with a userID as foreign key)
        For later
            - ingredients
            - nutrients
4. Shoppinglist domain
5. Ensure the correct access control, validation and functionality
    - Resolve bugs, issues, etc
    - Attempt to determine flaws in the architecture to avoid technical debt in the future
    - FIX all issues harming the implementation of future features.
    - Important to do this at this stage

