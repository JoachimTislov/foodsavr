---
name: introspect
description: Explain which instructions drove a specific action, to improve those instructions.
argument-hint: "Which action or decision?"
disable-model-invocation: true
metadata:
  audience: human
---

Analyze the action or decision the user names. Report:

1. Which instructions influenced it: system, harness, `AGENTS.md`, skills, or user messages. Quote each.
2. The reasoning that led to the action.
3. Ambiguous or conflicting instructions that played a role, with the file and line to change.

For a full review of the agent environment, use `retro`.
