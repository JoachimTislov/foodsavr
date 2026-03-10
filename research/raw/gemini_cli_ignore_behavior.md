# Gemini CLI Ignore Behavior Research

## Question
Does Gemini CLI ignore files that are ignored by git?

## Answer
Yes, **Gemini CLI ignores files that are ignored by git by default**.

The CLI includes a configuration setting called `context.fileFiltering.respectGitIgnore` which is set to `true` by default. This ensures that any files or directories matched by your `.gitignore` patterns are excluded from the CLI's operations, such as when searching for files or loading workspace context.

In addition to `.gitignore`, Gemini CLI also supports:
- **`.geminiignore`**: A dedicated ignore file for Gemini CLI that follows standard gitignore conventions. It is also respected by default (`context.fileFiltering.respectGeminiIgnore` defaults to `true`).
- **Custom Ignore Files**: Users can define additional ignore files via the `context.fileFiltering.customIgnoreFilePaths` setting in `settings.json`.

Changes to these "respect" settings or adding custom ignore paths typically require a restart of the Gemini CLI session to take effect.

## Sources
- reference/configuration.md
- cli/gemini-ignore.md
