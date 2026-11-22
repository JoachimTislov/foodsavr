# ADR 0008: Feature modules, entitlements and plans

## Status

Accepted (explicit owner intent, 2026-11-22: plans and entitlements interview; the owner confirmed the decision summary). Tracked by Epic #381. Builds on the automation-runtime decision on #321 (interaction-driven, on-device first, no scheduled or always-on cloud jobs). Amended November 22, 2026 with the owner's answers to the open questions (follow-up on PR #380). Spec-ahead: nothing here is implemented yet.

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
- `trialable`: whether a one-time trial exists;
- `killSwitchable`: whether Remote Config may switch it off (default true; false for modules that give users access to their own data, inventory viewing and data portability, which have no Remote Config key).

A module can be disabled without touching any other module: callers ask the resolver, never a plan or a flag directly. The catalog shape is [contracts/feature-registry.schema.json](../contracts/feature-registry.schema.json); the catalog instance, plans and limits are [registries/feature-modules.yaml](../registries/feature-modules.yaml). The app bundles the catalog, so resolution works offline.

### Resolution order

A module is enabled for a user when all of these hold, checked in this order:

1. the build supports it (compiled in and available on the platform);
2. it is not switched off remotely (Firebase Remote Config kill switch, also used for gradual rollout); modules marked not kill-switchable skip this step;
3. the user's plan includes it, or the user has an active trial of it (a Plus user may trial a module they have not picked), or it is one of the user's Plus picks;
4. the user has not hidden it.

A module whose dependency resolves to disabled is disabled. Viewing your own data (`inventory`) and export and delete (`dataPortability`) are never kill-switchable and never plan-gated. In production, the bundled Remote Config default for paid (automation and cloud) modules is off until the pre-paid-launch sign-off is recorded ([ADR 0009](0009-legal-documents-per-environment.md)), so an unreachable Remote Config never enables them early; standard modules default on. Remote Config is only for kill switches and rollouts, never for plan gating, because its targeting is client-asserted.

### Plans and limits

- **Free** is the standard app and the growth plan: inventory, barcode and on-device receipt scanning with per-item confirmation, expiry tracking, default and custom reminders, basic insights (expiring soon, monthly used vs thrown away), meal suggestions, bulk actions with undo, export and delete, and sharing one inventory with one other person. Limits: 3 inventories, 200 items per inventory.
- **Plus** adds 2 paid on-device modules of the user's choice. Sharing stays at one inventory with one person.
- **Paid plans (Plus, Pro, Family)** have unlimited inventories and items. A fair-use limit exists against abuse only; it is not advertised and not part of the catalog.
- **Pro** (1 or 2 members) and **Family** (up to 6 members) include every module, full household features, and the cloud modules.
- Paid on-device modules: rules, auto shopping list, smart expiry (learned shelf life, auto-filled expiry), advanced insights (waste and spend trends, per-store spend, forecasts), auto-accept ingestion (high-confidence items added without per-item confirmation).
- Cloud modules (store purchase sync, cloud receipt reading) are Pro and Family only and launch with the move to Blaze.
- Limits apply only to internal features. Viewing, exporting and deleting your own data are never blocked.
- Photos are never stored on any plan; a scan photo is deleted after a successful scan. Product images are Open Food Facts links.

### Plus picks

A Plus subscriber picks 2 paid on-device modules and may swap them once a month, whatever the billing period (monthly or annual). Whether "a month" is a calendar month or a rolling 30 days is an open question.

### Trials

Each paid on-device module can be trialed once per user, for 14 days, without a card, started by the user. A Plus user may trial a module they have not picked, once per module. Cloud modules are not trialable.

### Downgrade and trial end

Nothing is lost; data becomes read-only instead:

- Over-limit inventories stay readable but are read-only until the user picks 3 active inventories.
- An inventory over the item limit is read-only; deleting items stays possible.
- Rules stay saved but paused.
- Every other module's data stays readable.

The same rules apply when a Plus pick is swapped out (the module's data is saved read-only and its rules pause) and when a Pro or Family subscription ends:

- Household members fall back to their own plan.
- Shared inventories stay visible to every member and stay editable within the free sharing limits (1 shared inventory with 1 person).
- Household rules pause.

### Households and minors

Pro and Family plans have a household. Minimum age to create an account or pay is 18, self-declared at sign-up and stored with the account ([ADR 0009](0009-legal-documents-per-environment.md)). An adult on Family may invite members aged 13 to 17, who join under that adult's consent (recorded with time and document version) and cannot buy anything or connect store accounts. The guardian withdraws consent by removing the member, which pauses the minor's account. Rules in a household are shared household rules with per-member overrides (#323). Household membership builds on group ownership (#197).

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
- **Billing**: RevenueCat everywhere. It is the single source of truth for who has paid, with one customer record, so a plan bought once works on every platform. The RevenueCat App User ID is the Firebase UID.
- **Platforms**: Google Play Billing on Android; RevenueCat Web Billing (Stripe) on web, from day one; the App Store on iOS, later.
- **MVA**: the owner registers for MVA once sales pass NOK 50,000 in 12 months.
- **Payment grace period**: 7 days (the Google Play grace period). The plan stays active during the grace period; the downgrade applies when RevenueCat reports the entitlement expired.
- **On-device enforcement**: paid on-device modules unlock in the app from RevenueCat customer info. A cracked build loses a sale, not money, because these modules cost the owner nothing to run.
- **Cloud enforcement**: cloud modules launch with Blaze. RevenueCat's Firebase integration writes a trusted entitlement document and claim, and Firestore rules and server code check it. No Cloudflare Worker or other non-Firebase proxy.

The entitlement shape is [contracts/entitlement.schema.json](../contracts/entitlement.schema.json).

### Postponed

- The monthly cloud allowance size for Pro and Family.
- Pay-as-you-go credit packs (for everyone).
- iOS.
- Lifetime purchase.

## Open questions

The owner answered the questions raised after the interview (November 22, 2026); the answers are in the decision text above. Not decided; implementation tickets must not assume an answer:

1. Whether the monthly pick swap counts calendar months or a rolling 30 days.
2. Whether Pro and Family may share inventories with people outside the household beyond the free values (1 inventory with 1 person). The registry uses the free values until decided.
3. How invited household members get a trusted plan copy for cloud modules: RevenueCat writes the trusted copy only for the subscriber's App User ID, so a member's copy must be derived from the subscriber's (for example by trusted server code on Blaze when membership changes) and removed when the subscriber's plan ends. Decide the mechanism before cloud-module gating (#389) and household plans (#388).

## Consequences

- Every feature call site goes through the resolver; adding a module means a registry entry, a Remote Config default, and no change to other modules.
- The free plan costs the owner about nothing; paid revenue does not depend on Blaze until cloud modules launch.
- Plan, trial and pick state for on-device modules is client-enforced; only cloud modules get a trusted server-side check.
- Downgrades need read-only modes in inventories and rules, and a "pick 3 active inventories" flow; a swapped-out pick and an ended household plan follow the same rules.
- Web checkout through RevenueCat Web Billing ships with the first paid release, so the web build needs a purchase flow. The research could not confirm Flutter web purchase support, so the web billing ticket proves it first.
- Household plans depend on group ownership (#197); cloud modules depend on the Blaze move ([ADR 0005](0005-deployment-levels.md), #254).
- Selling needs production legal documents and the pre-paid-launch review in [ADR 0009](0009-legal-documents-per-environment.md).
