# FoodSavr

> Running or steering the project? Read [For humans](doc/humans.md): the manual processes and nothing else.

[![Project Status: WIP – Work in Progress](https://img.shields.io/badge/status-WIP-orange.svg)](https://wip.badge.style) [![Format, Analyze, Check Localizations and Run Tests](https://github.com/JoachimTislov/foodsavr/actions/workflows/ci-checks.yml/badge.svg)](https://github.com/JoachimTislov/foodsavr/actions/workflows/ci-checks.yml) [![codecov](https://codecov.io/gh/JoachimTislov/foodsavr/branch/main/graph/badge.svg)](https://codecov.io/gh/JoachimTislov/foodsavr)

`FoodSavr` is a mobile application designed to help you reduce food 
waste, save time, and manage your grocery expenses efficiently. By tracking 
inventory and synchronizing with your meal planning, the application ensures you always know 
what you have and what you need.


<p align="center">
  <img src="assets/logos/foodsavr-logo.svg" alt="FoodSavr Logo" width="200"/>
</p>

## Key Features

- [x] **Barcode Lookup:** Scan product barcodes to automatically fetch product details.
- [x] **Inventory Overview:** A clear and concise overview of all your food supplies.
- [x] **Insightful Dashboard:** Get an at-a-glance overview of items expiring soon.
- [x] **Third-party integration (Rema Æ app):** Connect with supported grocery stores for easier purchase history import.
- [x] **Shopping List view:** A basic, manual list for groceries to buy, without direct connection to inventory levels.
- [x] **Customizable Settings:** Language, themes, and app behavior.
- [x] **Receipt Scanning:** Quickly add items to your inventory by scanning receipts.
- [ ] **Expiration Tracking:** Get timely reminders before your food expires to reduce waste. (local reminders planned — #198)
- [ ] **Consumption Analysis:** The app learns your consumption patterns to better predict when you'll run out of items. (auto-generated shopping list planned — #195)
- [ ] **Meal Planning Sync:** Integrate your inventory with meal plans to create your shopping list. (tracked in #196)

## Tech Stack

- **Framework:** [Flutter](https://flutter.dev/)
- **Language:** [Dart](https://dart.dev/)
- **Database:** [Cloud Firestore](https://firebase.google.com/docs/firestore)
- **Authentication:** [Firebase Authentication](https://firebase.google.com/docs/auth)

## Getting Started

Clone the repository and ask an agent to run `make setup`, or run it yourself. [For humans](doc/humans.md) lists the few steps that need you.

## How to Contribute

Agents start with the [source-of-truth index](specs/source-of-truth/INDEX.md).

Got an idea or want to fix something? Awesome! We have a few guidelines for contributing that are pretty different from most projects, especially regarding AI-assisted code.

Please check out our **[CONTRIBUTING.md](./CONTRIBUTING.md)** for the full scoop on how to get started.

## License

This project is licensed under the **PolyForm Noncommercial License 1.0.0**.
See the `LICENSE` file for the full legal terms.

This license allows for any non-commercial use, but you may not use the
software for commercial purposes.

---

## Documentation

Read the [published vision, specification, and documentation](https://joachimtislov.github.io/foodsavr/).

The canonical spec lives in [`specs/source-of-truth/`](specs/source-of-truth/INDEX.md).
