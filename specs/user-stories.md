# User stories

This is the canonical user-intent spec: what FoodSavr must do for the people using it. It absorbs the historical stories in `doc/plan/user-stories.md`, which stays as backlog material only. New intent here is owner-gated (ADR 0002) and comes from the November 27, 2026 web walkthrough feedback, tracked in #532. Stories describe the intended behavior; built state lives in [status.md](status.md), and the feedback items behind each change live in #532.

## Direction

Five rules shape every story below.

1. You decide your structure. Nothing is provisioned for you: no default inventory and no default shopping list exist until you create them. Empty states offer kickstarters — create, import, or scan — so setup never becomes tedious data entry.
2. Every way in is supported. Receipt scan, barcode scan, expiry scan, pasted text from another app, and picks from the global catalog are all first-class import paths that can start with one scan and finish later.
3. Every way out is supported. Export covers all, some, or one section, inventory, or shopping list, with fewer steps on mobile and more control on PC.
4. The layout adapts to the platform and stays consistent. One spacing and sizing system serves every view; wide screens get desktop affordances instead of stretched mobile sizing.
5. Notifications respect you. Every banner, including "Install app", is dismissible and disappears once its reason is fulfilled.

## First run

A brand-new account starts empty and guided, never pre-filled.

- As a new user, I want to create my own inventory and shopping list as a simple step, so that what exists in my account is what I chose.
- As a new user, I want to delete anything created for me, so that no undeletable, oddly named list is stuck in my account.
- As a new user, I want the dashboard's inventory and shopping sections to show a create fallback when none exists, so that I know exactly where to start.
- As a new user, I want kickstarters like an essentials catalog import or a receipt scan, so that a working inventory takes minutes, not typing.

## Sign-in and account

- As a user, I want to sign up and log in with email and password or Google and Facebook, so that I can reach my data my way.
- As a social-login user, I want the app to detect my sign-in method and offer "Add password" instead of "Forgot password", so that the action matches my account.
- As a user, I want failures from a missing guest, Google, or Facebook setup surfaced clearly, so that I am never stuck on a silent blank screen.
- As a desktop user, I want a logout button in the main view, so that signing out is one click, not a settings journey.
- As a user, I want two-factor authentication either working or hidden, so that settings never advertise something I cannot use.

## Dashboard

The dashboard is the home of the app; inventory and shopping are sections of it.

- As a user, I want inventory and shopping-list views as dashboard sections, so that everything I track is one scroll away.
- As a user, I want widgets and entry points on the dashboard — scan receipt, import, export, integrations when they exist — so that I know where to click without hunting through views.
- As a user, I want an "All products" widget instead of a "View all" link, so that the dashboard covers the overview directly.
- As a user, I want a horizontal task bar with language, theme, and logout toggles, so that frequent controls sit in one place.
- As a user, I want quick actions like "Create product" to open a modal on the dashboard, so that I never lose my place to a wide dedicated view.
- As a user, I want a register-new-expiry fallback whenever a view has no expiry to show, so that a dead end becomes an action.

## Inventory

- As a user, I want to see, search, filter, and sort my products, so that I always know what I have.
- As a user, I want expiry reminders, so that food is used before it wastes.
- As a user, I want to add products by barcode scan or manual entry, so that either a camera or a keyboard is enough.
- As a user, I want a small icon per product when it is cheap to support, so that lists are scannable even without image support.
- As a user, I want badges that never collide and sit above the search field, so that the list header stays readable on wide screens.

## Shopping

- As a user, I want a shopping section on the dashboard, so that planning purchases stays next to my inventory.
- As a user, I want to mark items as bought so inventory updates automatically, and duplicates merged, so that the list stays truthful.
- As a user, I want to paste a word-based list from another app, so that moving to FoodSavr does not mean retyping.

## Imports and ingestion

Any scan can start the record; details can arrive later.

- As a user with a camera, I want product creation to start by scanning the barcode, so that manual entry is a fallback, not the default.
- As a user without a camera, I want "Add product" with unlimited barcode attempts and basic validation, so that one typo does not restart the flow.
- As a user, I want partial-search results from the foods API listed as candidates, so that a half-remembered barcode still finds the product.
- As a user, I want to scan an expiry date first and fill in the missing details later, so that a receipt or package goes in with one gesture.
- As a user, I want "Add product" to offer global catalog products covering the essentials, so that common items are one tap away.
- As a user, I want camera-permission errors handled with clear state, retry, and persistence, so that I control the access and can recover from a denied grant.

## Settings

Settings are a fixed-width, centered column; exports and connections live in it.

- As a user, I want settings laid out at a fixed width with centered rows, so that nothing stretches into hard-to-read lines.
- As a user, I want small shorthand toggles for language and dark/light mode in the task bar, so that switching is one click and replaces the dual-language selector.
- As a user, I want a section per social provider showing connection status, so that I can connect or disconnect Google and Facebook in place.
- As a user, I want camera access as an optional settings toggle, so that I can grant or revoke deliberately.
- As a user, I want "Delete Account" placed with account actions, not under "About", so that destructive and informational settings are separate.
- As a user, I want account and legal flows such as "Delete Account", terms of service, and privacy notice to open as small modals like "New Shopping List", each reachable through the URL state, so that they are consistent, linkable from outside (for example the Facebook app's policy links), and render a sensible default state directly.
- As a user, I want the export section to offer all, some, or one section, inventory, or shopping list, so that mobile gets fast taps and PC gets granular control.

## Platform behavior

- As a returning user, I want the first paint in my selected theme's color with a loader until the app resolves to login or dashboard, so that startup never flashes the wrong color or a blank screen.
- As a desktop user, I want zoom with Ctrl and +/- or the scroll wheel, so that I control how much I see.
- As a mobile user, I want pinch to zoom, so that the app obeys the platform's natural gesture.
- As a desktop user, I want hover states, cursors, and focus rings that signal interactivity, so that it is obvious what reacts to a click.
- As a user, I want desktop-appropriate border radius and spacing, so that wide screens do not wear mobile sizing.
- As a desktop user, I want breadcrumbs for quick navigation, so that deep views are one click back up; on mobile a back button is enough.
- As a user, I want buttons placed by platform detection and window size, so that actions like "Scan receipt" center correctly at any width.
- As a user on any browser, I want to install the app as a PWA, so that Firefox on mobile and PC works as well as Chromium.
- As a user, I want blue links without button highlight or hover, so that navigation reads as text, darker and calmer.
- As a user, I want notifications dismissible and self-hiding, so that fulfilled prompts like "Install app" never linger.

## Test data and web configuration

- As a developer, I want the test environment seeded with global products that have valid barcodes, so that scan and search flows are verifiable.
- As a developer, I want public client configuration served from the GitHub `test` environment and nested into the app bundle, so that the web never serves a raw `.env` file. Anything the client can read is public by definition: private credentials never reach the browser. A backend or proxy holds them and makes the integration requests on the client's behalf.

## Legal and brand

- As a user, I want finalized privacy policy and terms of service with a real contact (`dev.joachim.tislov@gmail.com`), so that the drafts I read are the documents that govern.
- As a user, I want a classically designed, transparent LettMat logo, so that the app's identity matches its intent.

## Not planned

Product image support is not planned; per-product icons are in scope only while they stay cheap. Historical wishlist stories (recipes, meal plans, groups) remain backlog in `doc/plan/user-stories.md` and are not canonical intent until separately owner-gated.
