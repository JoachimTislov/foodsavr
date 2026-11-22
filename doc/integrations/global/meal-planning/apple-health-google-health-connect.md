---
id: global-apple-health-google-health-connect
name: Apple Health / Google Health Connect (nutrition data)
scope: global
category: meal-planning
operator: Apple / Google
access: [api-public]
auth: oauth2
data: [nutrition]
item_level: true
cost: free
user_base: Billions of devices
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Apple Health / Google Health Connect (nutrition data)

On-device health stores that aggregate nutrition entries logged by other apps (MyFitnessPal, Cronometer, Lose It!, Yazio). A single integration there receives consumption from many trackers.

## Access

- **api-public** - Apple HealthKit (`HKQuantityTypeIdentifierDietaryEnergyConsumed` etc., with `HKCorrelationTypeIdentifierFood`) via on-device permission; Android Health Connect `NutritionRecord` via permission. Flutter plugin: `health`.

## Data

Nutrition records with energy, macros, micros, meal type, optional food name.

## FoodSavr mapping

Consumption data for waste/usage analysis; no barcodes; write path can log meals cooked from FoodSavr plans.

## Risks and constraints

- Read-only on device; data quality depends on source app; sensitive health data (GDPR special category).

## Existing work

- Flutter `health` package on pub.dev.

## Sources

- https://developer.apple.com/documentation/healthkit - HealthKit
- https://developer.android.com/health-and-fitness/guides/health-connect - Health Connect
- https://pub.dev/packages/health - Flutter plugin
