# Research: Smart Expiration Estimation (OFF & Categories)

## Objective
Reduce manual input by using product metadata (categories and previous entries) to estimate expiration dates when OCR or manual entry is skipped.

## Strategy 1: Open Food Facts Metadata
- **Field:** `expiration_date` (Raw string).
- **Usage:** Attempt to parse this string using a suite of Regex patterns. If it matches a date format, use it as the default.
- **Limitation:** This data is often missing or unnormalized in the OFF database.

## Strategy 2: Category-Based Defaults (The "Smart Default" Layer)
Map Open Food Facts category tags to a "Standard Shelf Life" table.

### Example Mapping Table
| OFF Category Tag | Default Duration | Storage |
| :--- | :--- | :--- |
| `en:milks` | 10 days | Fridge |
| `en:yogurts` | 14 days | Fridge |
| `en:canned-foods` | 730 days | Pantry |
| `en:frozen-foods` | 180 days | Freezer |
| `en:fresh-fruits` | 5 days | Counter |

## Strategy 3: User Heuristics (Learning)
- Track the user's average time between "Adding" and "Expiring" for specific brands.
- If a user always consumes a specific bread brand in 4 days, set the default to `AddedDate + 4 days`.

## Proposed Application Workflow
1. **Barcode Scan:** Identifies product and category (e.g., "Tine Helmelk", Category: "Milks").
2. **Auto-Estimate:** App sets a "Smart Default" based on category (Today + 10 days).
3. **OCR Check (Optional):** User can point camera at the date to refine the accuracy.
4. **Manual Override:** User taps the date to adjust if the estimate is wrong.