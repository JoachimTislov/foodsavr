---
name: analysis
description: Structural and architectural codebase analysis. Use when evaluating code structure, styling, location, reusability, and encapsulation.
---
# Analysis

This skill defines the process for analyzing code structure, architecture, and styling.

## Objective
Provide deep, structural insights into the codebase. Focus on how code is organized, where it lives, how it is styled, and how effectively it encapsulates its logic.

## Focus Areas
- **Code Structure & Location**: Are files placed in the correct architectural layers (e.g., Domain, Data, Service, UI)? Does the file location reflect its usage scope?
- **Encapsulation & Markup**: Keep components tightly scoped. Include markup in the same file if it is not used elsewhere. Avoid premature abstraction unless logic or UI components are verifiably duplicated.
- **Reusage**: Identify legitimately duplicated code across multiple files that should be extracted into shared components or utilities.
- **Styling**: Ensure alignment with project-specific formatting, naming conventions, and UI design token usage.

## Process
1. Read the provided files, diffs, or directories.
2. Evaluate them against the focus areas (Structure, Location, Encapsulation, Reusage, and Styling).
3. Output the structural findings concisely, using the format below.

## Output Format
Provide a structured analysis grouped by architectural concerns:

```markdown
### Analysis Summary

#### Structure & Location
* **[LOCATION]**: Detail if files/classes are in the wrong layer or directory.

#### Encapsulation & Reusage
* **[ENCAPSULATION]**: Detail whether local markup/logic is properly kept in the same file if not reused, or if it leaks context.
* **[REUSE]**: Highlight duplicated code that needs extraction.

#### Styling & Conventions
* **[STYLE]**: Note deviations from project styling and design standards.
```
