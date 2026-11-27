# Research: feature flags, subscriptions and entitlements for FoodSavr (Spark first)

Topic id: `entitlements-and-flags-2026-11`. Retrieved November 22, 2026 via harness web search (citations below). Non-authoritative research input to [ADR 0008](../../specs/decisions/0008-feature-modules-entitlements-and-plans.md); where the ADR differs (for example, no Cloudflare Worker), the ADR wins. No pages were fetched locally, so no HTTP status or hash is recorded. No injection or hidden-content tripwire fired. All page text was treated as data. Per the no-edit instruction, nothing was written to `.agents/ledger.jsonl` or `.agents/sessions/index.jsonl` (skill step 9 skipped).

Repo context used: `deploy/instance.yaml` (region `europe-north1`, Spark limits), ADR 0005 (levels ladder), `TODO.md:81` (payment integration backlog), `pubspec.yaml` (ML Kit text recognition and barcode are already on-device; no Remote Config or purchases package yet).

Confidence markers: **[V]** official source confirms it. **[P]** partly verified (official page plus conflicting third-party pages, or an official snippet only). **[U]** unverified (third-party only, or from memory). FX assumption: 1 USD ≈ 10.5 NOK **[U]**; I did not check the late-2026 rate.

**Update 2026-11-22 (owner decision, [ADR 0008](../../specs/decisions/0008-feature-modules-entitlements-and-plans.md)).** Web billing now uses RevenueCat Web Billing (Stripe) from day one, with RevenueCat as the single customer record across Play Billing, web and later the App Store. This supersedes the "Android first, web later" reading of sections 2d and 6 below. The research below is unchanged and keeps its original markers: RevenueCat Flutter web purchase support stays **[P]** and unverified (see "Not verified / open items"), so the web billing ticket proves it before building on it. The statement that Play policy forbids steering Android users to web prices stays **[U]** and is re-checked at the pre-paid-launch review. The owner registers for MVA once sales pass NOK 50,000 in 12 months (threshold **[P]**); EU VAT on web sales to EU consumers stays **[U]**. Also superseded: photos are never stored on any plan (receipt and product photos are deleted after a successful scan), so the "Store receipt images in Cloud Storage" step in section 6 does not apply.

---

## 1. Feature flags and remote config

| Option | Free tier | Flutter SDK (Android + web) | Offline | Per-user targeting | Kill-switch latency | Cost at 1k / 10k / 100k MAU (20 sessions per user per month) |
|---|---|---|---|---|---|---|
| Firebase Remote Config | Free on Spark and Blaze, no request quota **[V]**. Limits: 3,000 params, 2,000 conditions, 24 experiments plus rollouts **[V]** | Official `firebase_remote_config`. Real-time `onConfigUpdated` from v4.0.0. Web real-time support conflicts between docs pages **[P]** | Last activated values plus in-app defaults | Conditions on app version, country, language, percentile, Analytics user properties, custom signals (Flutter BoM 3.6.0+, 100 signals) **[P]**. All are client-set, so this is not a security boundary | Seconds in the foreground (real-time). Otherwise the fetch interval | $0 / $0 / $0 |
| Plain Firestore doc (`config/flags`, `users/{uid}/…`) | Counts against 50k reads per day on Spark **[V]** | Official `cloud_firestore`, good on both platforms | Offline cache (web persistence must be enabled) | Exact per-UID docs that only an admin can write. This is a real security boundary when rules check it | About 1 s with a listener. Each change costs 1 read per connected client | $0 / $0 (about 13% of the daily read quota) / about $1.2 per month on Blaze (2M reads at ≤$0.06 per 100k **[U]**). Above roughly 66k flag reads per day, it alone exceeds Spark |
| GrowthBook | Cloud Starter: 3 users, unlimited flags **[V]**. About 1M CDN requests per month **[U]**. OSS self-host is free | `growthbook_sdk_flutter` v4.x, lists web. SSE streaming via `backgroundSync` **[P]** | Cached payload | Rich attribute targeting, evaluated locally | Seconds with SSE (Cloud or proxy) | $0 / $0 / $0–40 (Pro is $40 per seat if the CDN cap is hit **[U]**) |
| Unleash | OSS self-host is free (1 project, 2 envs) **[P]**. Cloud is about $75 per seat **[U]** | Frontend SDK needs Unleash Edge or the frontend API (that is a server). Flutter SDK quality not verified **[U]** | Bootstrap and cache | Strategies and constraints | Polling (about 15 s default) **[U]** | Self-host plus a server / same / same. Cloud from $75 per month |
| Flagsmith | 50k requests per month, 1 seat **[V]** | `flagsmith` 6.x, Android plus web **[P]**. Offline behaviour not documented **[U]** | Cache API exists **[P]** | Identities and traits, segments | Polling. Real-time is a higher tier **[U]** | $0 / $45 (Start-Up, 1M) / about $45 plus overage or a higher plan **[P]** |
| PostHog | 1M `/flags` requests per month free **[V]** | `posthog_flutter` 5.x supports iOS, Android and web **[P]** | Persists the last flags | Person properties and cohorts | Next reload (app start or `reloadFeatureFlags`). No client streaming **[U]** | $0 / $0 / about $100 (1M paid × $0.0001) **[V for rate]** |
| LaunchDarkly | Developer: 1k client-side MAU **[P]** | `launchdarkly_flutter_client_sdk` 4.x, web plus WASM since 4.11 **[P]** | Persisted cache | Strongest (contexts, segments) | Streaming, sub-second | $0 / about $90–100 / about $900–1,000 per month at about $10 per 1k MAU **[P]** |

**Recommendation.** Use Remote Config for global switches (kill switch, staged rollout, defaults per locale). It costs nothing, works on Spark and is real-time on Android. On web, also fetch on start with a short minimum fetch interval, because the docs conflict on web real-time support. Do **not** use it for plan gating, because its targeting is client-asserted. Keep the plan → feature matrix as a shaped registry in the repo (ADR 0004), bundled in the app, so it works offline. Evaluate:

`enabled(feature) = !remoteKill[feature] && planIncludes(entitlement.plan, feature) && userSetting[feature]`

Take `entitlement.plan` from a trusted-written custom claim or doc (section 3). The SaaS flag tools add cost and a second SDK without solving entitlement. Reconsider GrowthBook (free, local evaluation) only if you need experiments beyond Remote Config's 24.

---

## 2. Subscriptions and entitlements (Android + web, iOS later)

### 2a. Vendors

| Vendor | Platforms | Server-side receipt validation without your backend | Webhooks / Firebase | Pricing |
|---|---|---|---|---|
| Google Play Billing (direct) | Android | No. Validation needs the Play Developer API from a trusted server. RTDN needs a Pub/Sub topic **[V]**, which is not available on Spark **[V]** | RTDN via Pub/Sub | Store fee only |
| App Store (direct) | iOS | No. Needs App Store Server API from a server | App Store Server Notifications | Store fee only |
| Stripe (direct, web) | Web | Stripe is the system of record, but you need a webhook receiver to reflect status into Firebase. The Firebase "Run Payments with Stripe" extension requires Blaze plus Functions **[V]** | Webhooks | Norway cards 2.4% + NOK 2 (EEA/domestic), 3.25% + NOK 2 (international) as of the 2023 notice **[P]**. Stripe Tax about 0.5% per transaction **[U]** |
| RevenueCat | Android, iOS, web (RevenueCat Billing, Stripe, Paddle) | Yes. RevenueCat validates with the stores **[V]** | Webhooks with signature header **[V]**. The Firebase "function kit" (replaces the deprecated extension) writes customer docs to Firestore and sets the `revenueCatEntitlements` custom claim, but it is a 2nd-gen Cloud Function and **needs Blaze** **[V]**. App User ID must equal the Firebase UID **[V]** | Free up to $2,500 MTR, then 1% (whether 1% applies to all revenue or only the excess is unclear) **[P]** |
| Adapty | Android, iOS, web paywalls | Yes | Webhooks, integrations | Free up to $5k MTR, then 1% (Feb 2026 change; older pages say $10k) **[P]** |
| Qonversion | Android, iOS, Flutter | Yes | Webhooks | Free under $10k MTR (official page) or $7k (Oct 2026 third-party), then about 0.6–0.8% **[P]** |

Flutter web caveat: RevenueCat's Flutter SDK added web via Web Billing. Its 2025 posts say product fetching, purchasing and restore through the Flutter SDK, plus `purchases_ui_flutter` paywalls, were not available on web. The standard pattern is a Web Purchase Link or Stripe Checkout redirect **[P]**. I could not confirm whether that changed in 2026.

### 2b. Store fees (Norway is in the EEA)

| Channel | Fee for auto-renewing subscriptions |
|---|---|
| Google Play, US/EEA/UK from 2026-06-30 | 10% service fee on subscriptions (and on the first $1M) plus a 5% billing fee when using Play Billing, so about 15% in total. The billing fee does not apply to alternative billing or external links **[P]**. Older global schedule: 15% on subscriptions **[V]** |
| Google Play, EEA alternative billing / external offers | Service fee reduced; external offers have their own fee schedule. Sources disagree (10% subscriptions, per-install fees) **[P]**. Norway is an eligible country **[V]** |
| Apple, Small Business Program (< $1M) | 15% **[V]** |
| Apple EU terms (2026-10-01) | 15% IAP / 10% alternative or link-out for small developers. Applies to the **EU**. Whether Norway (EEA, not EU) is covered was **not verified** **[U]** |
| Web (Stripe / Paddle / Vipps) | Payment fees only (section 2c), no store fee |

### 2c. VAT and merchant of record

- **Play and App Store sales:** Google determines, charges and remits Norwegian VAT for Play purchases **[V]**. Apple is believed to do the same **[U]**. Prices must be tax-inclusive in Norway **[V]**.
- **Web sales with Stripe direct:** the owner is the seller. A Norwegian business registers for MVA (25%) once it reaches NOK 50,000 turnover in 12 months **[P]**. Selling digital services to EU consumers from Norway likely means EU VAT via the non-Union OSS from the first sale **[U]**. Stripe Tax only calculates; it does not file **[U]**.
- **Merchant of record (they carry VAT and filings):** Paddle at 5% + $0.50 **[P]**. Lemon Squeezy has the same headline rate and is Stripe-owned **[P]**. Stripe Managed Payments adds about 3.5% on top of processing **[U]**. On a NOK 39 subscription, Paddle's fixed $0.50 alone is about 13%, so MoR pricing favours annual plans.
- **Vipps MobilePay Recurring:** the Recurring API needs an order for "Faste betalinger", extra Finanstilsynet-driven compliance and a Norwegian merchant **[V]**. Reported fee: 2.99% + NOK 1 per charge (third-party citing the Vipps price list) **[U]**. It needs a server holding API credentials (no client-only flow), has no RevenueCat integration **[U]**, and inside a Play-distributed Android app it may only be offered through the EEA alternative billing program. Best used as a **web** option for Norwegian households.

### 2d. Web vs in-app rules

- **Android (Play):** in-app sales of digital subscriptions must use Play Billing, unless the app enrolls in an EEA program (alternative billing with or without user choice, or external offers/link-out). Norway is eligible **[V]**. An external-offers app cannot also use Play Billing or User Choice Billing **[V]**. Outside these programs, do not steer users to web prices in-app. Letting users sign in and use a plan bought on the web is the usual multi-platform pattern **[U]** (from memory of the Payments policy; re-check the current policy text).
- **Web (PWA/Hosting):** any processor is allowed (Stripe, Paddle, Vipps).
- **iOS later:** IAP is required by default. Link-out rights exist in the EU and US under separate terms; Norway's status was not verified **[U]**.

**Recommendation.** Use RevenueCat as the entitlement source of truth: Play Billing on Android, RevenueCat Web Billing (Stripe) or a Paddle web config on web, App Store later. It costs $0 below $2.5k MTR (about NOK 26k per month), validates receipts without your backend, and one `entitlement` (`plus`, `household`) spans all stores. Defer Vipps until web revenue justifies a small server. Keep EEA alternative billing out of scope until revenue makes a 3–5 point fee difference worth the compliance work.

---

## 3. Enforcement on Spark

| Mechanism | Who writes | Works on Spark? | Security | Notes |
|---|---|---|---|---|
| Client gating from RevenueCat `CustomerInfo` | Client SDK | Yes | Bypassable (a patched APK or web devtools unlocks it) | Fine for on-device features: piracy costs revenue, not spend |
| Firestore rules reading `entitlements/{uid}` via `get()` | Trusted party with a service account | Yes. Admin/REST access to Firestore does not require Blaze **[U]** | Secure if the doc is not client-writable | Each rule `get()` is billed as 1 read |
| Firestore rules or servers reading the custom claim `request.auth.token.plan` | Trusted party via Admin SDK or the Identity Toolkit REST API | Yes **[U]** | Secure | Free to read. Up to about 1 h staleness until the ID token refreshes; force `getIdToken(true)` after purchase. 1,000-byte claim limit **[U]** |
| RevenueCat Firebase function kit | RevenueCat webhook → your Cloud Function | **No, needs Blaze** **[V]** | Secure | Official path once on Blaze |
| Stripe Firebase extension | Stripe webhook → Functions | **No, needs Blaze** **[V]** | Secure | — |
| Non-Google serverless webhook receiver (for example a Cloudflare Worker, free: 100k requests per day, 10 ms CPU **[V]**) | RevenueCat/Stripe webhook → Worker verifies the signature → writes the claim and doc via Google REST with a service-account token | Yes; Firebase stays on Spark | Secure (secret kept in Worker secrets, registered via `scripts/secrets/rotate.py`) | Not verified: RS256 JWT signing for the Google token within 10 ms CPU (cache the access token). Needs a prototype |
| Pull refresh (client calls Worker `/refresh-entitlement`; Worker calls RevenueCat REST with the secret key and writes the claim) | Same | Yes | Secure | Avoids webhooks. Respect RevenueCat REST rate limits **[U]** |

**Stopping free users from triggering paid server work.** Every paid server job (cloud OCR/LLM, store sync) must go through a trusted endpoint that:

1. Verifies the Firebase ID token and App Check token.
2. Checks the `plan` claim.
3. Decrements a per-user quota doc before calling the vendor.

Calling Firebase AI Logic directly from the client cannot be gated by plan. App Check only proves the request comes from the genuine app, not that the user paid. A single snippet says AI Logic requires App Check enforcement from 2026-11-02 **[U]**. So on Spark, paid LLM features need a proxy (a Worker), or must be accepted as client-gated with low per-user rate limits.

**A vendor webhook cannot write Firestore without some compute you control.** RevenueCat's only built-in Firestore writer is the Blaze-only function kit **[V]**. A Worker or similar is the Spark workaround.

**Recommendation.** Phase A (now): client-gate on-device paid features from RevenueCat `CustomerInfo`. Ship no paid cloud features. Phase B: add one Worker as the trusted writer and paid-work proxy, with the `plan` claim plus `entitlements/{uid}` (admin-only rules). Phase C (Blaze): replace the Worker with the RevenueCat function kit plus Cloud Run.

---

## 4. Cost model

### Inputs

- Firestore Standard prices used as an upper bound: reads $0.06 per 100k, writes $0.18 per 100k, deletes $0.02 per 100k, storage about $0.18 per GiB-month. These are nam5-style numbers; europe-north1 rates were not found **[U]**.
- Cloud Run: about $0.000024 per vCPU-s, with a free tier of 180k vCPU-s, 360k GiB-s and 2M requests per month **[P]**.
- Gemini: Flash-Lite about $0.30 / $2.50 per 1M input/output tokens; Flash about $1.50 / $7.50–9.00 (snapshots conflict; one source reports a December price increase) **[U]**.
- Document AI Expense parser: $0.10 per document of up to 10 pages **[V]**.
- FCM, ML Kit and local notifications: $0 **[V]** (ML Kit is from memory **[U]**).

### Per-receipt cloud parse

- About 1.5k input tokens (image plus prompt) and 0.8k output tokens.
- Flash-Lite: about $0.0025. Flash: about $0.009. Document AI: $0.10 (10–40× the LLM cost, with no line-item normalization).

### Per user per month

| Profile | Assumptions | Firestore | Cloud | Total USD | Total NOK |
|---|---|---|---|---|---|
| Free (on-device OCR, parser, rules, local notifications, projections) | 20 active days, about 50 reads and 10 writes per day, 0.2 MB stored | about $0.001 | $0 | **about $0.001** | **about 0.01** |
| Mid tier (adds cloud receipt parsing, 10 per month, Flash-Lite; FCM reminders) | Same Firestore plus 10 parses | about $0.001 | about $0.03 | **about $0.03** | **about 0.3** |
| Top-tier household (4 members, about 6 devices, 500 items, 30 parses per month on Flash, 30 on-demand store syncs on Cloud Run at about 2 vCPU-s each) | about 12k reads and 1.8k writes per month (listener re-reads after more than 30 min offline dominate) | about $0.01 | LLM about $0.27; Cloud Run about $0.0015 (inside the free tier) | **about $0.30** | **about 3** |

Store fees dominate: 15% of a NOK 39 plan is about NOK 6, which is more than the top-tier compute.

**Firestore read drivers to watch:** full listener re-sync after reconnect, rule `get()` calls, and per-session flag docs. Use offline persistence, `limit`, narrow listeners and claims instead of rule `get()`.

### Spark ceilings (from `deploy/instance.yaml`, confirmed by search)

| Resource | Spark limit |
|---|---|
| Firestore reads | 50k per day **[V]** |
| Firestore writes | 20k per day **[V]** |
| Firestore deletes | 20k per day **[V]** |
| Firestore storage | 1 GiB **[V]** |
| Firestore egress | 10 GiB per month **[P]** |
| Auth (Identity Platform) | 3k DAU on Spark (50k MAU free on Blaze); legacy Auth has no cap **[P]** |
| Hosting | 10 GB storage; 360 MB per day transfer (sources conflict) **[P]** |
| Unavailable | Functions, Cloud Run, Pub/Sub **[V]**; new Cloud Storage buckets (Blaze since 2024-10-30), and legacy Spark bucket access ended 2026-02-03 **[V]** |
| Over-quota behaviour | The product shuts off for the rest of the period **[V]** |

**Read ceiling:** about 1,000 DAU at 50 reads per user-day (roughly 3–5k MAU). Writes cap near 2,000 DAU.

### Blaze becomes necessary when any of these happen

1. Reads near 50k per day.
2. Auth near 3k DAU (Identity Platform).
3. You need the RevenueCat function kit, the Stripe extension, Play RTDN (Pub/Sub), Cloud Run store sync or Cloud Storage for receipt images.
4. Gemini usage beyond the free tier through AI Logic. Linking billing moves the Firebase project to Blaze **[V]**.

The Gemini Developer API free tier may use prompts for product improvement. One source says EEA users get paid-tier data handling **[U]**. Verify this before sending receipts (personal data) on the free tier.

---

## 5. Comparable apps

| App | Free | Paid | Price | Trial | Family / household |
|---|---|---|---|---|---|
| AnyList | Lists, sharing, 5 recipe imports | Complete: unlimited imports, web/Mac, meal plan | $9.99/yr individual, $14.99/yr household **[V]** | Yes **[U]** | Household tier |
| Paprika | — | Historically one-time per platform ($4.99 mobile, $29.99 desktop). Reported Nov 2026 switch to Premium at $14.99/yr intro, $9.99/yr upgrade **[U]** | — | 7 days **[U]** | Sync across own devices |
| Plan to Eat | — | Recipes, planner, lists | $5.95/mo or $49/yr **[P]** | 14 days **[P]** | Account sharing **[U]** |
| Mealime | Core planner | Pro (nutrition, more recipes) | About $2.99–5.99/mo (conflicting). One source reports shutdown on 2026-10-21 **[U]** | — | — |
| NoWaste | Inventory (fridge, freezer, pantry), barcode, sync | Pro: 255M-product scanner | $6.99/yr, $29.99 lifetime (US App Store) **[P]** | — | Shared sync |
| Kitche | Everything free: barcode/receipt import, recipes, waste-cost tracking **[P]** | — | — | — | — |
| Too Good To Go | Free for consumers; pay per bag (Norway e.g. NOK 79 for a NOK 177 bag) **[P]** | Businesses pay commission plus annual fee **[P]** | — | — | — |
| Bring! | Shared lists, recipes | Premium: no ads, themes, photos, web | €17.99/yr (IE), $8.99/yr (US), €9.99/yr (RS); NOK price not found **[P]** | — | Sharing is free |
| KitchenPal | Inventory, lists | Premium | $3.99/mo, $14.99/yr, $29.99 lifetime **[P]** | — | — |
| Pantry: Life Storage | Inventory | Pro: unlimited photos, bulk add | $3.49/mo, $23.99/yr **[P]** | — | — |

**Pattern:** the free tier keeps core inventory, barcode and sharing. Paid tiers cost $7–25 a year and add automation or convenience: bigger product database, imports, web access, photos, no ads. Household plans are about 1.5× individual. Lifetime offers and 7–14 day trials are common.

**Hypothesis (not validated):** price FoodSavr below meal-planning apps and near pantry apps:

- Free.
- Pluss: about NOK 19/mo or 149/yr.
- Husstand: about NOK 39/mo or 299/yr.

Use annual-first pricing to reduce the impact of fixed per-transaction fees.

---

## 6. Recommended stack

### Spark now (owner cost about $0 per month)

1. **Flags:** Firebase Remote Config (kill switches, rollouts) plus a bundled plan → feature registry in the repo. Feature modules check `enabled(feature)` (section 1).
2. **Purchases:** RevenueCat (free under $2.5k MTR) with Play Billing on Android. Web purchases via a RevenueCat Web Purchase Link with Stripe (or Paddle as MoR, to avoid owning VAT filings). App User ID = Firebase UID.
3. **Enforcement:** client-side from `CustomerInfo` for on-device paid features (OCR rules, projections, local notifications, advanced automation). These cost the owner nothing, so bypass risk is revenue-only.
4. **No paid cloud features yet.** If needed before Blaze, add one free-tier Worker as the trusted writer and proxy: webhook → `plan` custom claim plus admin-only `entitlements/{uid}`, and the LLM proxy with per-user quota. This needs a prototype (JWT CPU budget, secret registration in `scripts/secrets/registry.toml`).
5. **Push:** FCM (free). Most reminders should stay local notifications.

### On Blaze (add budget alerts; ADR 0005 requires a declared budget)

1. Replace the Worker with the RevenueCat Firebase function kit (custom claims plus Firestore customer docs).
2. Firestore rules check `request.auth.token.revenueCatEntitlements` (or a derived `plan`).
3. Enable Play RTDN via Pub/Sub in RevenueCat for faster renewal and cancel updates.
4. Run paid cloud work (receipt LLM via Cloud Run or AI Logic with App Check plus a per-user limit, and store sync) behind an ID-token and claim check. Store receipt images in Cloud Storage.
5. Consider Remote Config conditions on custom signals for UX only, never for gating.
6. Later options: Vipps Recurring on web (server now available), EEA alternative billing on Play, and iOS via the same RevenueCat entitlements.

---

## Not verified / open items

- Firestore europe-north1 per-operation prices (upper-bound US figures used).
- Gemini current model names and prices; the December 2026 increase; EEA free-tier data handling.
- AI Logic App Check requirement from 2026-11-02 (single snippet).
- Remote Config real-time on Flutter web (docs conflict); whether user-property conditions need the Analytics SDK.
- RevenueCat Flutter web: current support for purchase and restore, and `purchases_ui_flutter` on web. Now on the critical path: web checkout through RevenueCat Web Billing ships with the first paid release (owner decision, 2026-11-22), so the web billing ticket proves it first.
- Whether selling on web from day one before MVA registration (below NOK 50,000 in 12 months) and the EU VAT position for EU consumers hold; confirm at the pre-paid-launch review.
- Google Play fees after 2026-06-30 (new vs existing installs; external offers fee schedule). Check the Play Console fee table.
- Apple: whether EU terms apply to Norway, and whether Apple remits Norwegian VAT.
- Vipps Recurring official price; Stripe Norway 2026 card rates; Stripe Tax and Managed Payments rates.
- Whether Admin and REST writes to Firestore and Auth claims from an external service account work on Spark (expected yes; prototype it).
- Comparable-app NOK prices (Bring!, AnyList), Paprika's 2026 change, Mealime shutdown.

## Sources (retrieved 2026-11-22)

- Firestore quotas: https://firebase.google.com/docs/firestore/quotas
- Firebase pricing plans: https://firebase.google.com/docs/projects/billing/firebase-pricing-plans
- Firebase pricing: https://firebase.google.com/pricing
- Firestore pricing: https://cloud.google.com/firestore/pricing
- Firestore locations: https://docs.cloud.google.com/firestore/native/docs/locations
- Remote Config real-time (Flutter): https://firebase.google.com/docs/remote-config/flutter/real-time
- Remote Config get started (Flutter): https://firebase.google.com/docs/remote-config/flutter/get-started
- Remote Config quotas: https://firebase.google.com/docs/remote-config/quotas-limits
- Remote Config conditions: https://firebase.google.com/docs/remote-config/parameters/client
- Auth limits: https://firebase.google.com/docs/auth/limits
- Storage changes FAQ: https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- Firebase AI Logic pricing: https://firebase.google.com/docs/ai-logic/pricing
- Gemini API pricing: https://ai.google.dev/gemini-api/docs/pricing
- Third-party Gemini pricing (unverified): https://fastero.com/blog/gemini-api-pricing, https://www.lilachbullock.com/is-gemini-api-free/
- Document AI pricing: https://cloud.google.com/document-ai/pricing
- Cloud Run pricing: https://cloud.google.com/run/pricing
- Cloudflare Workers limits: https://developers.cloudflare.com/workers/platform/limits
- GrowthBook: https://growthbook.io/pricing, https://docs.growthbook.io/lib/flutter, https://pub.dev/packages/growthbook_sdk_flutter
- Unleash: https://getunleash.io/pricing, https://costbench.com/changelog/unleash-plans-renamed-2026-02/
- Flagsmith: https://flagsmith.com/pricing, https://docs.flagsmith.com/clients/flutter/
- PostHog: https://posthog.com/feature-flags/pricing, https://posthog.com/docs/libraries/flutter/reference
- LaunchDarkly: https://www.launchdarkly.com/pricing, https://launchdarkly.com/docs/sdk/client-side/flutter
- RevenueCat pricing: https://www.revenuecat.com/pricing
- RevenueCat Firebase function kit: https://www.revenuecat.com/docs/integrations/third-party-integrations/firebase-function-kit
- RevenueCat Firebase integration: https://www.revenuecat.com/docs/integrations/third-party-integrations/firebase-integration
- RevenueCat Flutter web support: https://www.revenuecat.com/blog/engineering/flutter-sdk-web-support/
- RevenueCat Flutter install: https://www.revenuecat.com/docs/getting-started/installation/flutter
- RevenueCat app-to-web guidelines: https://www.revenuecat.com/app-to-web-purchase-guidelines
- Adapty: https://adapty.io/pricing/, https://adapty.io/blog/adapty-new-pricing-2026/
- Qonversion: https://qonversion.io/pricing, https://www.gappsy.com/tools/qonversion/
- Play service fees: https://support.google.com/googleplay/android-developer/answer/112622
- Play fee changes June 2026: https://android-developers.googleblog.com/2026/06/play-expanded-billing.html
- Play fee changes March 2026: https://android-developers.googleblog.com/2026/03/a-new-era-for-choice-and-openness.html
- Play EEA alternative billing: https://support.google.com/googleplay/android-developer/answer/12348241
- Play external offers: https://support.google.com/googleplay/android-developer/answer/14372887
- Play tax: https://support.google.com/paymentscenter/answer/7161449
- Play tax-inclusive pricing: https://support.google.com/googleplay/android-developer/answer/138000
- Play RTDN: https://developer.android.com/google/play/billing/getting-ready
- Apple EU changes Aug 2026: https://www.apple.com/newsroom/2026/08/apple-announces-changes-for-apps-in-the-european-union/
- Apple Small Business Program: https://developer.apple.com/app-store/small-business-program/
- Stripe Norway pricing update: https://support.stripe.com/questions/pricing-updates-for-businesses-in-norway
- Stripe Firebase extension: https://firebase.google.com/docs/tutorials/payments-stripe
- Firebase Extensions install: https://firebase.google.com/docs/extensions/install-extensions
- Paddle pricing: https://paddle.com/pricing
- Paddle vs Lemon Squeezy: https://resources.rework.com/tools/billing-revenue/paddle-vs-lemon-squeezy
- Norway VOEC registration: https://www.skatteetaten.no/en/business-and-organisation/vat-and-duties/vat/foreign/e-commerce-voec/register
- Altinn VAT for foreign companies: https://info.altinn.no/en/start-and-run-business/direct-and-indirect-taxes/indirect-taxes/vat-specific-information-for-foreign-companies/
- Vipps Recurring API: https://developer.vippsmobilepay.com/docs/APIs/recurring-api/recurring-api-guide
- Vipps billing and recurring: https://vippsmobilepay.com/online/billing-recurring
- Vipps fee, third-party (unverified): https://quasa.io/no/media/vipps-eller-stripe-lenke-500-kroner-gir-bare-55-oere-i-forskjell
- AnyList: https://www.anylist.com/premium, https://help.anylist.com/articles/individual-household-upgrade
- Meal-planning roundup (Mealime, Paprika, Plan to Eat; unverified): https://www.bestmoney.com/financial-advisor/learn-more/meal-planning-app-saving-money
- Mealime: https://www.mealime.com/lower-prices
- NoWaste: https://apps.apple.com/us/app/nowaste-food-inventory-list/id926211004
- Kitche: https://agritechobservatory.review.fao.org/es/kitche, https://theindexproject.org/award/nominees/6439
- Too Good To Go: https://apps.apple.com/NO/app/id1060683933, https://toogoodtogo.com/en-gb/business
- Bring!: https://apps.apple.com/ie/app/id580669177, https://www.nerdwallet.com/finance/learn/best-grocery-list-apps
- KitchenPal: https://adapty.io/paywall-library/kitchenpal-shared-grocery-list/
- Pantry: Life Storage Organizer: https://apps.apple.com/us/app/id1541163843
