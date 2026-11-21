---
name: check-loop
description: "Run make check, fix what fails, commit, and repeat until green; then push."
disable-model-invocation: true
metadata:
  audience: human
---

1. Split the work into independent changes; apply one, with its tests and docs.
2. Run `make check`. On failure, read the errors, fix them, and run it again.
3. Stop and report when the same errors persist after a fix attempt, or after two consecutive failures.
4. When green, commit with the `commit` skill and run `make push`. A failed push returns to step 2.
5. Repeat for the next change, then summarize the changes as bullet points.
