# ADR 0009: Legal documents per environment

## Status

Accepted (explicit owner intent, 2026-11-22: plans and entitlements interview; the owner confirmed the decision summary). Tracked by Epic #381. Amended November 22, 2026 with the owner's answers to the open questions (follow-up on PR #380). Spec-ahead: today the app bundles one English privacy notice and one terms of service for every environment (`assets/legal/`, `lib/constants/legal_docs.dart`).

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
- Existing accounts must accept the first versioned documents on their next launch. Export and delete stay available without accepting.

The manifest and acceptance shapes are [contracts/legal-documents.schema.json](../contracts/legal-documents.schema.json).

### Operator, law and languages

- The operator is the owner as a private person, under Norwegian law and the GDPR.
- Documents exist in Norwegian Bokmål (`nb`) and English (`en`).
- The published contact address (operator and data requests) is a new dedicated FoodSavr mailbox, not the owner's personal email. Until the owner provides it, manifests carry the placeholder `legal-contact@placeholder.invalid`.

### Age

- The minimum age to create an account or pay is 18. The user self-declares 18 or older at sign-up; the declaration is stored with the account (`ageDeclaration` in the contract).
- An adult on a Family plan may invite members aged 13 to 17. They join under that adult's consent and cannot buy anything or connect store accounts.
- The guardian's invite records consent with the time and the version of the document consented to (`guardianConsent` in the contract). The guardian withdraws consent by removing the member, which pauses the minor's account.

### Pre-paid-launch legal review

Production does not go live with paid plans until a legal review gate has passed: a checklist the owner signs off before the first paid release. Until then, paid-plan prototyping stays in the test environment. The owner accepted these checklist items:

1. The privacy policy lists every processor and data category (Firebase, RevenueCat, Stripe through RevenueCat Web Billing, Google Play, Open Food Facts) and the data-request route.
2. The subscription terms cover renewal, cancellation, trials, downgrade, households and the Norwegian right of withdrawal for digital services.
3. The age rules (18 or older self-declared, guardian-invited 13 to 17) are reflected in sign-up and the documents.
4. The nb and en texts match, and the landing page (#371) serves the same versions as the app.
5. Account deletion and export work in production (#354, #352).
6. The store listing privacy URL and data-safety form match the documents.

Production Remote Config keeps paid modules off until the sign-off is recorded (also accepted by the owner).

## Open questions

Not decided by the owner; implementation tickets must not assume an answer.

1. Whether anyone besides the owner reviews the gate checklist (the owner accepted the checklist items but named no other reviewer).
2. Proposed, not yet accepted, as additional gate items: the production contact placeholder is replaced by the dedicated mailbox; the unverified research items on web sales (VAT before and after MVA registration, Play's rule against steering Android users to web prices) are re-checked.

## Consequences

- Legal text becomes per-environment data with a loader, instead of two hard-coded asset paths.
- Production sign-up and paywall flows depend on versioned acceptance.
- Non-production environments still need privacy handling of real data (deletion, export, processors).
- The first paid production release is blocked on the review gate, not only on code.
