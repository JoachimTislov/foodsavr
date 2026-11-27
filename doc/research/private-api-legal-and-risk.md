# Private grocery APIs: legal and operational risk notes

This document summarizes the legal, contractual, and operational risks of
integrating undocumented or mobile-app-only grocery APIs (such as Rema 1000 Æ,
Coop Medlem, and Trumf) on behalf of consenting users. It is engineering
research, not legal advice.

## Why private APIs are risky

Major Norwegian grocery chains do not offer public consumer receipt APIs.
Third-party receipt aggregators typically integrate by acting as a client on
behalf of a consenting user ("Bring Your Own Credentials") against endpoints
originally built for first-party mobile apps. Because those endpoints are
undocumented and unsupported, integrations sit at the intersection of four
areas of law and operations.

## Legal and contractual dimensions

The risk profile depends on whether access uses a consenting user's own
credentials and stays within interoperability boundaries.

### Copyright and interoperability

- **EU Software Directive (2009/24/EC), Article 6:** Permits decompilation when
  it is indispensable to obtain the information needed for interoperability
  between independent programs, and declares contractual clauses that forbid
  that right null and void.
- **US law:** *Google v. Oracle* (2021) and DMCA Section 1201(f) provide narrow
  interoperability protections, though they do not shield tools aimed at
  bypassing access controls for unauthorized copying.

### Contract law and Terms of Service

Most retail loyalty apps prohibit automated access, scraping, and reverse
engineering in their Terms of Service (ToS).

- Breaching a ToS is a civil contract matter rather than a criminal offense.
- In practice, grocers enforce ToS restrictions through technical blocking
  (rate limits, IP blocks, token invalidation, account suspension) and
  cease-and-desist notices against commercial aggregators.
- Within the EU/EEA, statutory interoperability and data-portability rights
  weaken blanket anti-interoperability clauses, but do not eliminate dispute
  or enforcement risk for a commercial service.

### Computer crime statutes

Statutes targeting "unauthorized access" (such as the US CFAA and European
equivalents) focus on bypassing authorization barriers.

- Accessing a user's own account using credentials or OAuth tokens explicitly
  granted by that user is generally treated as authorized access rather than
  hacking.
- Risk rises sharply if a service accesses data beyond the consenting user's
  account, reuses leaked credentials, or circumvents server-side authorization
  controls.

### GDPR data portability

Under **GDPR Article 20**, individuals have the right to receive personal data
they provided in a structured, machine-readable format and transmit it to
another controller without hindrance.

- Consumer-consented receipt tools rely on Article 20 and Article 15 (right of
  access) to justify retrieving a user's own purchase history.
- Where a retailer already offers a manual GDPR data export (for example,
  in-app JSON receipt export), supporting that export avoids ToS friction
  entirely.

## Operational risks

Even when legal risk is low for personal or user-consented use, private APIs
carry high maintenance cost:

- **Silent breaking changes:** App updates can rotate client IDs, change OAuth
  flows, alter response schemas, or enforce stricter certificate pinning and
  bot detection without notice.
- **Cloud IP blocking:** Centralized backend polling from cloud IP ranges is
  more likely to trigger anomaly detection than on-device requests.
- **Credential liability:** Storing raw user passwords (instead of scoped OAuth
  refresh tokens) increases security exposure and user trust risk.

## Guidance for FoodSavr

Apply these guardrails when planning or building grocery integrations:

1. **Prefer official APIs and user exports first:** Support OCR receipt
   scanning, barcode enrichment (Open Food Facts, Kassal.app, or licensed
   registries), and retailer GDPR JSON exports before relying on private APIs.
2. **Require explicit user consent:** Clearly disclose what data FoodSavr
   reads and never collect credentials or tokens without informed opt-in.
3. **Avoid storing raw passwords:** Prefer OAuth 2.0 / OIDC PKCE tokens stored
   in platform secure storage on the client rather than centralized password
   vaults.
4. **Isolate fragile clients:** Keep each store client behind an integration
   interface, monitor `401`/`403`/`404` spikes, and prompt users to reconnect
   or fall back to receipt scanning when an upstream API changes.

## Related documents

- [Norwegian grocery private API integration plan](../plan/grocery-private-api-integration.md)
- [Storebox receipt integration research](storebox_integration.md)
- [Source-of-truth integrations](../../specs/integrations.md)
