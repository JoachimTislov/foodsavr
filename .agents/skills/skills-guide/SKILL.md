---
name: skills-guide
description: Ask which skill or flow fits your situation. A router over this repository's skills.
disable-model-invocation: true
metadata:
  audience: human
---

# Skills guide

The full list, split into agent and human skills, is the generated [catalog](../README.md). Before stating what a skill does or recommending a step be skipped, read that skill's `SKILL.md`: the summaries here orient only.

A **flow** is a path through the skills. Most work travels the **main flow**; **on-ramps** merge onto it.

## Main flow: idea → ship

1. **`/grilling`** sharpens the idea by interview; in the repo it runs with `domain-modeling`, so resolved terms and decisions land in `specs/source-of-truth/`.
2. **Need a runnable answer** (state, logic, a UI to see)? Detour through **`/prototype`**, bridged by **`/handoff`** out and back.
3. **Multi-session build?** **`/to-spec`**, then **`/to-tickets`** (tracer-bullet tickets with blocking edges), then **`/implement`** per ticket with fresh context, or `/implement` on the whole spec to orchestrate the frontier in parallel. Otherwise `/implement` here.

   `implement` drives **`tdd`** and **`flutter-standards`**, closes with **`code-review`** (Standards + Spec axes), commits with **`commit`**, and opens the PR with **`pr`**. Review feedback goes through **`resolve-pr-comments`**; landing the queue is **`pr-merge`**.

4. **`/retro`** closes the loop: it improves the agent environment (pointers, checks, standards, steering files), not the code. **`/introspect`** is its single-action version.

Keep steps 1–3 in one unbroken context window until `/to-tickets`; compact at a phase boundary if the session nears the model's smart zone. [PHASE-BOUNDARIES.md](PHASE-BOUNDARIES.md) has the continue / clear / handoff / subagent / compact tree.

## On-ramps

- **Raw issues piling up** → **`/triage`** produces `triage/ready-for-agent` issues that `implement` (or a runner) picks up. Tickets from `/to-tickets` are already agent-ready.
- **Something broken** → **`diagnosing-bugs`**: a tight red loop first, then the fix with a regression test.
- **Many ready issues, several agents** → **`queue-planner`** plans a batch of parallel lanes with disjoint file footprints and an integration order.
- **A huge, foggy effort** → **`/wayfinder`** charts decision tickets until the way is clear, then hands off at `/to-spec`.

## Codebase health

- **`/improve-codebase-architecture`** surveys deepening opportunities; **`codebase-design`** is the vocabulary to design the chosen one.

## Standalone

- **`research`**: cited, quarantined external research.
- **`/to-questionnaire`**: a questionnaire for someone who holds knowledge you lack.
- **`wizard`**: an interactive script for steps only a human can take.
- **`/check-loop`**: `make check`, fix, commit, repeat until green.
- **`/compress-memory`**, **`/wait-what`** (re-pitch the last message), **`/teach`** (learn a topic over sessions).
- **`writing-for-agents`** and **`docs-writer`**: writing for agents and for humans.
