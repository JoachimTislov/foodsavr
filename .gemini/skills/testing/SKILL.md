---
name: testing
description: Use this skill when asked to write or run tests
---

# Source Code Testing Guide

Follow these instructions for writing and running tests in the FoodSavr project.

1. **Write Unit Tests for Business Logic:**
   - Create unit tests for models and services in `test/`.
   - Focus on testing validation, orchestration, and business rules.

2. **Create Widget Tests for UI Components:**
   - Write widget tests to verify layout, rendering, and interaction of reusable components.
   - Use `package:flutter_test` for these tests.

3. **Implement Integration Tests:**
   - Create integration tests for end-to-end user flows in `test/`.
   - Use the `integration_test` package to verify the full application behavior.

4. **Use Mocks and Fakes for Dependencies:**
   - Prefer using fakes or stubs over mocks.
   - Use `mockito` or `mocktail` for more complex mocking of external dependencies.

5. **Run Tests Regularly:**
   - Run tests using `flutter test` or `make check` before committing changes.
   - Ensure that all tests pass and that there are no regressions.
   - Use Firebase emulators for integration tests.
