# ADR 0008: Feature modules, entitlements and plans

## Status

Accepted (explicit owner intent, 2026-11-22: plans and entitlements interview; the owner confirmed the decision summary). Tracked by Epic #381. Builds on the automation-runtime decision on #321 (interaction-driven, on-device first, no scheduled or always-on cloud jobs). Spec-ahead: nothing here is implemented yet.

## Context

FoodSavr runs on Firebase Spark at about zero cost to the owner (`deploy/instance.yaml`, [ADR 0005](0005-deployment-levels.md)). Automation runs on the device when the user interacts (#321). The owner wants a growth-oriented free app, paid automation, household plans, and the ability to switch any feature off remotely without a release. Nothing in the code models a feature, a plan, or an entitlement today; every feature is always on. Research with sources and confidence markers: [doc/research/entitlements-and-flags-2026-11.md](../../../doc/research/entitlements-and-flags-2026-11.md) (non-authoritative).

## Decision

### Feature modules

Every user-facing capability is a **feature module**. A module declares:

- an `id`;
- its `dependencies` (other module ids); a module is usable only when all of its dependencies are usable;
- a `costClass`: `onDevice` (runs in the app; only standard Firestore storage) or `cloud` (needs paid server compute, so Blaze);
- an `entitlement`: the key the plan table grants;
- `userHideable`: whether the user may hide it;
- `trialable`: whether a one-time trial exists.

A module can be disabled without touching any other module: callers ask the resolver, never a plan or a flag directly. The catalog shape is [contracts/feature-registry.schema.json](../contracts/feature-registry.schema.json); the catalog instance, plans and limits are [registries/feature-modules.yaml](../registries/feature-modules.yaml). The app bundles the catalog, so resolution works offline.

### Resolution order

A module is enabled for a user when all of these hold, checked in this order:

1. the build supports it (compiled in and available on the platform);
2. it is not switched off remotely (Firebase Remote Config kill switch, also used for gradual rollout);
3. the user's plan includes it, or the user has an active trial of it, or it is one of the user's Plus picks;
4. the user has not hidden it.

A module whose dependency resolves to disabled is disabled. Remote Config is only for kill switches and rollouts, never for plan gating, because its targeting is client-asserted.

### Plans and limits

- **Free** is the standard app and the growth plan: inventory, barcode and on-device receipt scanning with per-item confirmation, expiry tracking, default and custom reminders, basic insights (expiring soon, monthly used vs thrown away), meal suggestions, bulk actions with undo, export and delete, and sharing one inventory with one other person. Limits: 3 inventories, 200 items per inventory.
- **Plus** adds 2 paid on-device modules of the user's choice. Sharing stays at one inventory with one person.
- **Pro** (1 or 2 members) and **Family** (up to 6 members) include every module, full household features, and the cloud modules.
- Paid on-device modules: rules, auto shopping list, smart expiry (learned shelf life, auto-filled expiry), advanced insights (waste and spend trends, per-store spend, forecasts), auto-accept ingestion (high-confidence items added without per-item confirmation).
- Cloud modules (store purchase sync, cloud receipt reading) are Pro and Family only and launch with the move to Blaze.
- Limits apply only to internal features. Viewing, exporting and deleting your own data are never blocked.
- Photos are never stored on any plan; a scan photo is deleted after a successful scan. Product images are Open Food Facts links.

### Plus picks

A Plus subscriber picks 2 paid on-device modules and may swap them once per billing period.

### Trials

Each paid on-device module can be trialed once per user, for 14 days, without a card, started by the user. Cloud modules are not trialable.

### Downgrade and trial end

Nothing is lost; data becomes read-only instead:

- Over-limit inventories stay readable but are read-only until the user picks 3 active inventories.
- An inventory over the item limit is read-only; deleting items stays possible.
- Rules stay saved but paused.
- Every other module's data stays readable.

### Households and minors

Pro and Family plans have a household. Minimum age to create an account or pay is 18. An adult on Family may invite members aged 13 to 17, who join under that adult's consent and cannot buy anything or connect store accounts. Rules in a household are shared household rules with per-member overrides (#323). Household membership builds on group ownership (#197).

### Nudges

Upgrade prompts are value-based and sparse: a monthly summary of what automation would have done, and hints at the moment of need. At most one nudge per week, and the user can turn nudges off. Users choose which automation types matter to them.

### Prices

Starting points in NOK, adjustable, configured in the store and RevenueCat rather than in the app:

| Plan | Annual | Monthly |
|---|---|---|
| Plus | 199 | 25 |
| Pro | 349 | 45 |
| Family | 499 | 59 |

The paywall leads with annual. No lifetime purchase for now. The monthly prices were proposed in the interview alongside the owner-chosen annual prices and confirmed in the summary; treat them as a starting point.

### Services and enforcement

- **Flags**: Firebase Remote Config for kill switches and gradual rollout (free on Spark and Blaze). The plan-to-module table is the bundled registry, not Remote Config.
- **Billing**: RevenueCat is the single source of truth for who has paid; Google Play Billing on Android. The RevenueCat App User ID is the Firebase UID.
- **Web**: Android sells first. Web users can sign in and use what they bought. Web checkout comes later through RevenueCat Web Billing with Stripe, once revenue justifies registering for MVA (above NOK 50,000 in 12 months).
- **iOS**: later, through RevenueCat and the App Store.
- **On-device enforcement**: paid on-device modules unlock in the app from RevenueCat customer info. A cracked build loses a sale, not money, because these modules cost the owner nothing to run.
- **Cloud enforcement**: cloud modules launch with Blaze. RevenueCat's Firebase integration writes a trusted entitlement document and claim, and Firestore rules and server code check it. No Cloudflare Worker or other non-Firebase proxy.

The entitlement shape is [contracts/entitlement.schema.json](../contracts/entitlement.schema.json).

### Postponed

- The monthly cloud allowance size for Pro and Family.
- Pay-as-you-go credit packs (for everyone).
- Web checkout (see above) and iOS.
- Lifetime purchase.

## Open questions

Not decided by the owner; implementation tickets must not assume an answer.

1. Paid-plan limits: are inventories and items unlimited on Plus, Pro and Family (the registry uses `null` for now), or higher finite limits?
2. May the Remote Config kill switch disable export and delete, given that exporting and deleting your own data is never blocked?
3. On an annual Plus plan, is "swap once per billing period" once a year?
4. When a Plus pick is swapped out, does its data follow the downgrade rules (for example, rules paused)?
5. May a Plus subscriber trial a module they have not picked?
6. When a Pro or Family subscription ends, what happens to household members, shared inventories and household rules?
7. Billing grace period and account-hold behavior (store billing retry) before a downgrade applies.

## Consequences

- Every feature call site goes through the resolver; adding a module means a registry entry, a Remote Config default, and no change to other modules.
- The free plan costs the owner about nothing; paid revenue does not depend on Blaze until cloud modules launch.
- Plan, trial and pick state for on-device modules is client-enforced; only cloud modules get a trusted server-side check.
- Downgrades need read-only modes in inventories and rules, and a "pick 3 active inventories" flow.
- Household plans depend on group ownership (#197); cloud modules depend on the Blaze move ([ADR 0005](0005-deployment-levels.md), #254).
- Selling needs production legal documents and the pre-paid-launch review in [ADR 0009](0009-legal-documents-per-environment.md).
