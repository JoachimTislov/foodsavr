---
name: localization
description: Use this skill when asked to write localization for managing translations and multi-language support.
---

# Localization Management Guide

Follow these instructions for managing translations and ensuring multi-language support in the FoodSavr project.

1. **Maintain Translation Files:**
   - Translations are stored in `assets/translations/`.
   - Supported locales: `en-US.json`, `nb-NO.json`.
   - When adding a key, ensure it is added to ALL translation files with appropriate translations.

2. **Use Descriptive Keys:**
   - Use nested JSON objects for scoping (e.g., `auth.login.title`, `error.network`).
   - Keys should be descriptive and use `snake_case`.

3. **Verify Synchronization:**
   - Always run `dart run tool/check_localizations.dart` after modifying translation files.
   - This script checks for missing keys across different locales.

4. **Implementation in UI:**
   - Use `.tr()` extension method from `easy_localization` on strings.
   - For plurals, use `plural()` and ensure appropriate keys (e.g., `zero`, `one`, `other`) are defined.
   - For parameters, use named arguments: `"activity.user_joined".tr(namedArgs: {'name': 'Joachim'})`.

5. **Code Generation for Keys:**
   - If the project uses generated keys, run:
     `dart run easy_localization:generate -S assets/translations -f keys -o locale_keys.g.dart`
