# GoRouter Sequential Test Isolation Bug

## Problem

Two new `testWidgets` for `test/router_auth_flow_test.dart` (suggested by CodeRabbit in [PR #14 comment r2837290495](https://github.com/JoachimTislov/foodsavr/pull/14#discussion_r2837290495)) pass individually but fail when run sequentially after the existing test.

After the first test navigates GoRouter to `/products`, subsequent tests get stuck on `SizedBox.shrink()` — GoRouter's "not ready" state when `matchList.isEmpty`.

## Tests to Add

```dart
// Test 2: authenticated user redirects to dashboard
testWidgets('redirects authenticated user from landing to dashboard', ...);

// Test 3: sign out redirects back to landing
testWidgets('redirects to landing after sign out', ...);
```

Both tests follow the same pattern as the existing test 1 and pass in isolation.

## Root Cause

Flutter's `RestorationManager` persists GoRouter's navigation state (`/products`) across `testWidgets` runs. When the next test builds a new `Router(restorationScopeId: 'router')`, GoRouter attempts async restoration from the stale state, leaving `matchList` empty indefinitely.

## Attempted Fixes (All Failed)

| Approach | Result |
|---|---|
| `UnmanagedRestorationScope(bucket: null)` wrapper | Still stuck on SizedBox |
| `restorationScopeId: null` on MaterialApp.router | No effect |
| `UniqueKey()` on root EasyLocalization widget | Forces fresh widget tree, still stuck |
| `ObjectKey(router)` on \_TestApp | Same result |
| `pumpWidget(SizedBox.shrink())` before mounting | Doesn't help |
| Extra `pump()` / `pump(Duration(seconds: 1))` calls | GoRouter never resolves |
| `router.refresh()` / `router.go('/')` when stuck | No effect |
| Mocking `flutter/restoration` platform channel | Broke test 1 too |
| Fully isolated auth/router/getIt per test (no shared setUp) | Still fails sequentially |
| Removing static `_rootNavigatorKey` from router.dart | Unrelated to the issue |
| Removing `router.dispose()` from tearDown | No effect |

## Key Technical Details

- **go_router version**: 17.1.0
- `GoRouterBuilder.build()` returns `const SizedBox.shrink()` when `matchList.isEmpty && !matchList.isError`
- `WidgetsApp` always creates `RootRestorationScope` regardless of `restorationScopeId`
- `pumpAndSettle()` completes (no pending frames), but GoRouter is waiting for async restoration that never finishes
- The redirect function in `router.dart` is synchronous — the async hang is entirely from the restoration system

## Possible Next Steps

1. **Investigate GoRouter's `RouterDelegate.restoreState`** — find why the async restoration never completes in test environment
2. **Reset the binding's `RestorationManager`** between tests (no public API found for this yet)
3. **File a go_router issue** — sequential `testWidgets` with GoRouter `refreshListenable` breaks due to restoration state leaking
4. **Restructure as separate test files** — each file gets a fresh isolate, avoiding the shared binding state entirely
5. **Use `integration_test`** instead of widget tests for router behavior

## PR Reference

- PR: https://github.com/JoachimTislov/foodsavr/pull/14
- CodeRabbit comment with test suggestions: https://github.com/JoachimTislov/foodsavr/pull/14#discussion_r2837290495
- Related review thread: https://github.com/JoachimTislov/foodsavr/pull/14#issuecomment-3941646747

## Existing Passing Test (for reference)

The first test (`redirects from landing page to main screen after authentication`) works because it runs first — the restoration bucket is empty, so GoRouter starts fresh.
