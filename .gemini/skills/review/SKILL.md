---
name: review
description: Standard code review skill. Produces short, precise, and highly concise feedback. Focuses on progressive feedback and future development details without non-progressive nitpicks.
---
# Review

This skill defines the standard process for performing code reviews.

## Objective
Deliver high-signal, actionable, and progressive feedback with extreme conciseness. Avoid conversational filler and non-progressive feedback (i.e., subjective nitpicks that don't improve the codebase). Include important details for future development.

## Guidelines
- **Short & Precise**: Use minimal text. Output direct bullet points.
- **Progressive Feedback Only**: Only point out issues that objectively improve the code's quality, safety, or architecture. Do not comment on stylistic preferences unless they violate explicit project rules.
- **Future Context**: Highlight architectural implications or technical debt that will affect future development.
- **Format Strictness**: Use bracket tags like `[BUG]`, `[PERF]`, `[ARCH]`, `[FUTURE]`, and `[FIX]`. Do not use markdown emphasis tags (like `_*_`) for categorizing.

## Output Format
Output your review exactly as follows:

```markdown
### Review Summary
* **[Category]**: FilePath:Line - Concise description of the issue or future implication.
  * **[FIX]**: `Exact replacement code or precise action.`
```

### Example

```markdown
### Review Summary
* **[BUG]**: `lib/views/dashboard.dart:80` - Unawaited future causes race conditions during refresh.
  * **[FIX]**: `await Future.wait([expiringSoon, inventories]);`
* **[FUTURE]**: `lib/services/auth.dart:45` - Hardcoded token logic will block the upcoming OAuth integration.
  * **[FIX]**: Inject token provider via constructor.
```
