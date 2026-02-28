---
name: issue-creator
description: Use this skill when asked to create an issue (bug, feature, or task). It ensures issues are clear, actionable, and follow repository standards.
---

This skill guides the creation of high-quality issues to track bugs, features, or tasks.

# Workflow

1.  **Research**: Verify the issue isn't a duplicate.
    - Use `gh issue list --search "your query"` to check for existing issues.
    - If the issue exists, add a comment to the existing issue instead of creating a new one.

2.  **Identify Type**: Determine if it's a `bug`, `feature`, or `task`.
    - **Bug**: Something is broken. Needs reproduction steps and expected vs. actual behavior.
    - **Feature**: New functionality. Needs a user story (As a [role], I want [goal] so that [benefit]).
    - **Task**: Maintenance or technical debt. Needs clear success criteria.

3.  **Draft Title**: Use a concise, descriptive title.
    - Follow [Conventional Commits](https://www.conventionalcommits.org/) if the repository uses it (e.g., `bug: fix crash on login`, `feat: add google auth`).

4.  **Draft Description**:
    - **Bugs**:
      - **Context**: Environment, version, etc.
      - **Steps to Reproduce**: 1, 2, 3...
      - **Expected Behavior**: What should happen.
      - **Actual Behavior**: What actually happened.
    - **Features**:
      - **User Story**: Use the format: *As a [role], I want [goal/functionality] so that [benefit].*
      - **Requirements**: Bullet points of what needs to be implemented.
    - **Tasks**:
      - **Goal**: What needs to be done.
      - **Acceptance Criteria**: How to know it's finished.

5.  **Create Issue**: Use the `gh` CLI. To avoid shell escaping issues with multi-line Markdown, write the description to a temporary file first.
    ```bash
    # 1. Write the drafted description to a temporary file
    # 2. Create the issue using the --body-file flag
    gh issue create --title "type: succinct description" --body-file <temp_file_path> --label "bug|feature|task"
    # 3. Remove the temporary file
    rm <temp_file_path>
    ```

# Principles

- **Actionable**: Every issue should have a clear path to resolution.
- **Atomic**: One issue per problem or feature.
- **Contextual**: Link related issues or PRs using `#issue_number`.
