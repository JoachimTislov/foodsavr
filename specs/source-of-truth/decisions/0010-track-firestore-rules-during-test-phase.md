# ADR 0010: Track Firestore rules during the test phase

## Status

Accepted (explicit owner intent, 2026-11-23). Supersedes the untracked-rules decision of #165 and #185. Revisit before a production environment exists.

## Context

`firestore.rules` was deliberately untracked. CI loaded it from the `FIRESTORE_RULES_B64` secret, and the owner applied rules to the Firebase project by hand. The three copies drifted:

- The secret and the live test project held an early prototype. In it, `isUser` used `!=` and `isAdmin` trusted `users/{uid}.role`, so any signed-in user could make themselves an admin.
- The rules suite failed 8 of 16 tests, unseen, because the job skips itself when the secret is unset or stale ([failing run](https://github.com/JoachimTislov/foodsavr/actions/runs/45229064879)).
- Nobody reviewed the rules against the paths the app uses.

Only the test environment exists today. It holds no production data.

## Decision

- Track `firestore.rules` at the repository root. The rules are reviewed in pull requests like code.
- The `Firestore security rules` job in `validation.yml` tests the tracked file in the Firestore emulator. A change to `firestore.rules` or `firestore-rules/**` triggers it. The `FIRESTORE_RULES_B64` secret and the skip-when-unset branch are removed.
- Deploys are manual: `make deploy-firestore-rules ENV=<environment>` deploys the tracked file to the Firebase project of that environment in `deploy/instance.yaml`. The release pipeline deploys rules in a later change.

## Consequences

- The rules are public. This is acceptable while only the test environment exists, because the rules protect by authentication and ownership, not by being secret.
- The tracked file, the CI test and the deployed rules can still drift until the release pipeline deploys them. Deploy after each rules change.
- Rules paths follow the app: `products`, `collections`, `users/{uid}/**`, `owners/{uid}/rawEvents` (create-only, ADR 0005), `runtime_errors` (create-only) and `roles` (admins read, nobody writes). Everything else is denied.
- The GitHub secret `FIRESTORE_RULES_B64` is unused; the owner can delete it.

## Revisit trigger

Before a production environment exists, the owner decides whether the rules stay in the public repository or move back out of it.
