# ADR 0009: Legal documents per environment

## Status

Accepted (explicit owner intent, 2026-11-22: plans and entitlements interview; the owner confirmed the decision summary). Spec-ahead: today the app bundles one English privacy notice and one terms of service for every environment (`assets/legal/`, `lib/constants/legal_docs.dart`).

## Context

Non-production environments mirror production and may hold real user data, but with no persistence guarantee. Paid plans ([ADR 0008](0008-feature-modules-entitlements-and-plans.md)) need subscription terms, and Google Play needs a public privacy policy URL. The same text must not drift between the app and the web.

## Decision

### Document set per environment

| Environment | Documents |
|---|---|
| `development`, `test`, `staging` | Tester terms: real data allowed, no persistence guarantee (data may be wiped). Privacy obligations still apply, because the data can be real. |
| `production` | Full privacy policy, terms of service, and subscription terms. |

Each environment has a single source for its document set. The app shows it (with a bundled offline copy of the same version) and the environment's public landing page hosts it (#371).

### Versioning and acceptance

- Every document has a version and a material-change flag per version.
- The app stores each user's acceptance per document version.
- A new version with a material change prompts the user to accept again; a non-material change does not.

The manifest and acceptance shapes are [contracts/legal-documents.schema.json](../contracts/legal-documents.schema.json).

### Operator, law and languages

- The operator is the owner as a private person, under Norwegian law and the GDPR.
- Documents exist in Norwegian Bokmål (`nb`) and English (`en`).

### Age

- The minimum age to create an account or pay is 18.
- An adult on a Family plan may invite members aged 13 to 17. They join under that adult's consent and cannot buy anything or connect store accounts.

### Pre-paid-launch legal review

Production does not go live with paid plans until a legal review gate has passed: a checklist the owner signs off before the first paid release. Until then, paid-plan prototyping stays in the test environment.

## Open questions

Not decided by the owner; implementation tickets must not assume an answer.

1. Which contact address the documents publish for the operator and for data requests.
2. How age is established at sign-up (for example, a self-declared birth date) and how a guardian's consent for members aged 13 to 17 is recorded and withdrawn.
3. Whether existing accounts must accept the first versioned documents on their next launch.
4. The review gate's checklist items and who, besides the owner, reviews them (the checklist ticket proposes candidates for the owner to confirm).

## Consequences

- Legal text becomes per-environment data with a loader, instead of two hard-coded asset paths.
- Production sign-up and paywall flows depend on versioned acceptance.
- Non-production environments still need privacy handling of real data (deletion, export, processors).
- The first paid production release is blocked on the review gate, not only on code.
